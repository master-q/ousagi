module Main where

import Prelude hiding (init)

import Control.Monad (when)
import Data.IORef
import System.Environment (getArgs, getProgName)
import System.Exit (exitSuccess, exitFailure)
import System.IO (hPutStrLn, stderr)
import System.FilePath (isRelative)
import System.Directory (getCurrentDirectory)

import qualified Data.Text as T

import qualified GI.Gtk as Gtk
import qualified GI.Gdk as Gdk
import qualified GI.GLib as GLib
import qualified GI.Cairo as GICairo

import GI.Cairo.Render
  ( Render
  , save, restore
  , translate, scale
  , moveTo
  , rectangle, fill
  , setSourceRGB, setSourceRGBA
  , liftIO
  )
import GI.Cairo.Render.Connector (renderWithContext)

import qualified GI.Pango as Pango
import qualified GI.PangoCairo as PangoCairo

import qualified GI.Poppler as Poppler

-- Default total presentation time in seconds (5 minutes)
defaultTotalTimeSec :: Double
defaultTotalTimeSec = 300.0

-- Application state (mutable parts in IORefs)
data AppState = AppState
  { appDoc                :: Poppler.Document
  , appTotalPages         :: Int
  , appCurrentPage        :: IORef Int
  , appPresRunning        :: IORef Bool
  , appElapsedSec         :: IORef Double
  , appLastUpdateSec      :: IORef Double
  , appDisplayedTimerProg :: IORef Double
  , appDisplayedPageProg  :: IORef Double
  , appTotalTimeSec       :: Double
  }

-- Get monotonic time in seconds
monotonicSec :: IO Double
monotonicSec = do
  t <- GLib.getMonotonicTime
  return (fromIntegral t / 1_000_000.0)

-- Toggle presentation timer start/stop
toggleTimer :: AppState -> IO ()
toggleTimer st = do
  running <- readIORef (appPresRunning st)
  if running
    then do
      now <- monotonicSec
      lastT <- readIORef (appLastUpdateSec st)
      modifyIORef' (appElapsedSec st) (+ (now - lastT))
      writeIORef (appPresRunning st) False
    else do
      now <- monotonicSec
      writeIORef (appLastUpdateSec st) now
      writeIORef (appPresRunning st) True

-- Update elapsed time if presentation is running
updateTimer :: AppState -> IO ()
updateTimer st = do
  running <- readIORef (appPresRunning st)
  when running $ do
    now <- monotonicSec
    lastT <- readIORef (appLastUpdateSec st)
    modifyIORef' (appElapsedSec st) (+ (now - lastT))
    writeIORef (appLastUpdateSec st) now

-- Draw the current PDF page scaled to fit the widget dimensions
drawPdfPage :: AppState -> GICairo.Context -> Int -> Int -> IO ()
drawPdfPage st ctx width height = do
  pageIdx <- readIORef (appCurrentPage st)
  page <- Poppler.documentGetPage (appDoc st) (fromIntegral pageIdx)
  (pw, ph) <- Poppler.pageGetSize page
  let fw    = fromIntegral width  :: Double
      fh    = fromIntegral height :: Double
      s     = min (fw / pw) (fh / ph)
      ox    = (fw - pw * s) / 2.0
      oy    = (fh - ph * s) / 2.0
  -- Fill background black
  renderWithContext (do
    setSourceRGB 0 0 0
    rectangle 0 0 fw fh
    fill
    save
    translate ox oy
    scale s s
    ) ctx
  -- Render PDF page onto the same cairo context (inherits the transform)
  Poppler.pageRender page ctx
  -- Restore transform
  renderWithContext restore ctx

-- Draw emoji progress indicator at position [0..1] along the bar
drawProgressText :: String -> Double -> Int -> Double -> GICairo.Context -> IO ()
drawProgressText text progress width y ctx = do
  layout <- PangoCairo.createLayout ctx
  desc <- Pango.fontDescriptionFromString (T.pack "Sans Bold 20")
  Pango.layoutSetFontDescription layout (Just desc)
  Pango.layoutSetText layout (T.pack text) (-1)
  (tw, _) <- Pango.layoutGetPixelSize layout
  let clamped = min (max progress 0.0) 1.0
      x       = clamped * max (fromIntegral width - fromIntegral tw :: Double) 0.0
  renderWithContext (moveTo x y) ctx
  PangoCairo.showLayout ctx layout

-- Draw the overlay bar with turtle (timer) and rabbit (page) progress
drawOverlay :: AppState -> GICairo.Context -> Int -> Int -> IO ()
drawOverlay st ctx width height = do
  elapsed     <- readIORef (appElapsedSec st)
  running     <- readIORef (appPresRunning st)
  currentPage <- readIORef (appCurrentPage st)
  dispTimer   <- readIORef (appDisplayedTimerProg st)
  dispPage    <- readIORef (appDisplayedPageProg st)

  let totalPages = appTotalPages st
      pageProg   = if totalPages > 1
                     then fromIntegral currentPage / fromIntegral (totalPages - 1)
                     else 0.0
      timerProg  = min (elapsed / appTotalTimeSec st) 1.0
      fh         = fromIntegral height :: Double
      fw         = fromIntegral width  :: Double
      -- Lerp smoothing (0.1 factor per frame)
      newTimerD  = if running
                     then dispTimer + (timerProg - dispTimer) * 0.1
                     else dispTimer
      newPageD   = dispPage + (pageProg - dispPage) * 0.1

  -- Update displayed progress
  writeIORef (appDisplayedTimerProg st) newTimerD
  writeIORef (appDisplayedPageProg  st) newPageD

  -- Draw semi-transparent background bar
  renderWithContext (do
    setSourceRGBA 0 0 0 0.3
    rectangle 0 (fh - 30) fw 30
    fill
    ) ctx

  -- Draw turtle emoji (timer progress) in green
  renderWithContext (setSourceRGB 0.2 0.8 0.2) ctx
  let turtleText = if running
                     then "\x1F422"          -- turtle
                     else "\x1F422\x1F4A4"   -- turtle + zzz
  drawProgressText turtleText newTimerD width (fh - 30) ctx

  -- Draw rabbit emoji (page progress) in red
  renderWithContext (setSourceRGB 0.9 0.3 0.3) ctx
  drawProgressText "\x1F407" newPageD width (fh - 30) ctx

-- Print usage help
printHelp :: String -> IO ()
printHelp prog = do
  putStrLn $ "Usage: " ++ prog ++ " [OPTIONS] PDF_FILE"
  putStrLn ""
  putStrLn "Options:"
  putStrLn "  -t MINUTES      Set presentation duration in minutes (default: 5)"
  putStrLn "  -h, --help      Show this help message and exit"
  putStrLn ""
  putStrLn "Keys:"
  putStrLn "  Space           Start or pause the presentation timer"
  putStrLn "  Left / Right    Move to the previous or next page"
  putStrLn "  Home / End      Move to the first or last page"
  putStrLn "  Esc             Quit"

-- Parse minutes string to seconds
parseMinutes :: String -> IO Double
parseMinutes s = case reads s of
  [(m, "")] | m > 0 -> return (m * 60.0)
  _ -> do
    hPutStrLn stderr "Error: presentation minutes must be greater than 0"
    exitFailure

-- Parse command-line arguments
parseArgs :: [String] -> IO (Double, Maybe String)
parseArgs args = go args defaultTotalTimeSec Nothing
  where
    go [] t f = return (t, f)
    go ("-h":_) _ _ = do
      prog <- getProgName
      printHelp prog
      exitSuccess
    go ("--help":_) _ _ = do
      prog <- getProgName
      printHelp prog
      exitSuccess
    go ("-t":v:rest) _ f = do
      t <- parseMinutes v
      go rest t f
    go ("-t":_) _ _ = do
      hPutStrLn stderr "Error: -t requires a value in minutes"
      prog <- getProgName
      printHelp prog
      exitFailure
    go (a:rest) t _ = go rest t (Just a)

main :: IO ()
main = do
  args <- getArgs
  (totalTimeSec, mFile) <- parseArgs args

  filename <- case mFile of
    Nothing -> do
      prog <- getProgName
      printHelp prog
      exitSuccess
    Just f  -> return f

  _ <- Gtk.init Nothing

  -- Build file URI for Poppler
  uri <- if isRelative filename
           then do
             cwd <- getCurrentDirectory
             return $ "file://" ++ cwd ++ "/" ++ filename
           else return $ "file://" ++ filename

  -- Load PDF document
  doc <- Poppler.documentNewFromFile (T.pack uri) Nothing

  nPages <- fromIntegral <$> Poppler.documentGetNPages doc

  -- Initialise app state
  st <- do
    cp  <- newIORef 0
    pr  <- newIORef False
    el  <- newIORef 0.0
    lu  <- newIORef 0.0
    dtp <- newIORef 0.0
    dpp <- newIORef 0.0
    return AppState
      { appDoc                = doc
      , appTotalPages         = nPages
      , appCurrentPage        = cp
      , appPresRunning        = pr
      , appElapsedSec         = el
      , appLastUpdateSec      = lu
      , appDisplayedTimerProg = dtp
      , appDisplayedPageProg  = dpp
      , appTotalTimeSec       = totalTimeSec
      }

  -- Create main window
  win <- Gtk.windowNew Gtk.WindowTypeToplevel
  Gtk.windowSetTitle win (T.pack "Pusagi (Haskell)")
  Gtk.windowSetDefaultSize win 1024 768
  _ <- Gtk.onWidgetDestroy win Gtk.mainQuit

  -- Overlay widget so the progress bar floats on top of the PDF view
  overlay <- Gtk.overlayNew

  -- Drawing area for the PDF
  pdfArea <- Gtk.drawingAreaNew
  Gtk.widgetSetCanFocus pdfArea True

  -- Drawing area for the overlay bar
  overlayArea <- Gtk.drawingAreaNew

  Gtk.containerAdd overlay pdfArea
  Gtk.overlayAddOverlay overlay overlayArea
  Gtk.containerAdd win overlay

  -- Connect PDF draw callback
  _ <- Gtk.onWidgetDraw pdfArea $ \ctx -> do
    w <- Gtk.widgetGetAllocatedWidth  pdfArea
    h <- Gtk.widgetGetAllocatedHeight pdfArea
    drawPdfPage st ctx (fromIntegral w) (fromIntegral h)
    return True

  -- Connect overlay draw callback
  _ <- Gtk.onWidgetDraw overlayArea $ \ctx -> do
    w <- Gtk.widgetGetAllocatedWidth  overlayArea
    h <- Gtk.widgetGetAllocatedHeight overlayArea
    drawOverlay st ctx (fromIntegral w) (fromIntegral h)
    return True

  -- Key press handling on the window
  _ <- Gtk.onWidgetKeyPressEvent win $ \ev -> do
    k <- Gdk.getEventKeyKeyval ev
    if | k == Gdk.KEY_Escape            -> do
             Gtk.widgetDestroy win
             return True
       | k == Gdk.KEY_space
         || k == Gdk.KEY_KP_Space       -> do
             toggleTimer st
             Gtk.widgetQueueDraw overlayArea
             return True
       | k == Gdk.KEY_Home              -> do
             writeIORef (appCurrentPage st) 0
             Gtk.widgetQueueDraw pdfArea
             Gtk.widgetQueueDraw overlayArea
             return True
       | k == Gdk.KEY_End               -> do
             writeIORef (appCurrentPage st) (nPages - 1)
             Gtk.widgetQueueDraw pdfArea
             Gtk.widgetQueueDraw overlayArea
             return True
       | k == Gdk.KEY_Right             -> do
             modifyIORef' (appCurrentPage st) (\p -> min (p + 1) (nPages - 1))
             Gtk.widgetQueueDraw pdfArea
             Gtk.widgetQueueDraw overlayArea
             return True
       | k == Gdk.KEY_Left              -> do
             modifyIORef' (appCurrentPage st) (\p -> max (p - 1) 0)
             Gtk.widgetQueueDraw pdfArea
             Gtk.widgetQueueDraw overlayArea
             return True
       | otherwise                      -> return False

  -- 60fps timer for smooth animation
  _ <- GLib.timeoutAdd GLib.PRIORITY_DEFAULT 16 $ do
    updateTimer st
    Gtk.widgetQueueDraw overlayArea
    return True

  Gtk.widgetShowAll win
  Gtk.widgetGrabFocus pdfArea

  Gtk.main
