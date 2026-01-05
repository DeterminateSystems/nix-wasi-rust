use std::env;
use std::fs;

fn main() {
    println!("START");

    let args: Vec<String> = env::args().collect();

    if args.len() < 2 {
        eprintln!("Usage: {} <name>", args[0]);
        std::process::exit(1);
    }

    let name = &args[1];
    let out_path = env::var("out").expect("$out environment variable not set");

    let message = format!("Hello {}", name);

    fs::write(&out_path, message).expect("Failed to write to $out");

    println!("DONE");
}
