use std::env;
use std::fs;

fn main() {
    eprintln!("Environment variables:");
    for (key, value) in env::vars() {
        eprintln!("  {}={}", key, value);
    }
    eprintln!();

    if let Ok(nix_build_top) = env::var("NIX_BUILD_TOP") {
        eprintln!("Contents of $NIX_BUILD_TOP ({}):", nix_build_top);
        match fs::read_dir(&nix_build_top) {
            Ok(entries) => {
                for entry in entries {
                    if let Ok(entry) = entry {
                        eprintln!("  {}", entry.file_name().to_string_lossy());
                    }
                }
            }
            Err(e) => eprintln!("  Error reading directory: {}", e),
        }
        eprintln!();
    }

    let args: Vec<String> = env::args().collect();

    if args.len() < 2 {
        eprintln!("Usage: {} <name>", args[0]);
        std::process::exit(1);
    }

    let name = &args[1];
    let out_path = env::var("out").expect("$out environment variable not set");

    let greeting_path =
        env::var("greetingPath").expect("$greetingPath environment variable not set");
    let greeting = fs::read_to_string(&greeting_path)
        .expect("Failed to read greeting file")
        .trim()
        .to_string();

    let message = format!("{} {}", greeting, name);

    fs::write(&out_path, message).expect("Failed to write to $out");
}
