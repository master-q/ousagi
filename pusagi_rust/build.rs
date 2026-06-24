fn main() {
    // Link against poppler-glib using pkg-config
    let output = std::process::Command::new("pkg-config")
        .args(["--libs", "poppler-glib"])
        .output()
        .expect("Failed to run pkg-config for poppler-glib");

    let libs = String::from_utf8(output.stdout).expect("pkg-config output not utf8");
    for flag in libs.split_whitespace() {
        if let Some(lib) = flag.strip_prefix("-l") {
            println!("cargo:rustc-link-lib={lib}");
        } else if let Some(path) = flag.strip_prefix("-L") {
            println!("cargo:rustc-link-search=native={path}");
        }
    }
    println!("cargo:rerun-if-changed=build.rs");
}
