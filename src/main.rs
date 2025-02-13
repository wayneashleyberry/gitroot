use clap::{Arg, Command};
use std::env;
use std::error::Error;
use std::fs;
use std::path::{Path, PathBuf};

fn main() -> Result<(), Box<dyn Error>> {
    let mut app = Command::new("gitroot")
        .about("Find and move to your git root directory")
        .subcommand(
            Command::new("find")
                .about("Find the root .git directory")
                .arg(
                    Arg::new("match")
                        .short('m')
                        .long("match")
                        .default_value("last")
                        .value_parser(["first", "last"])
                        .help("Use the first or last .git directory found"),
                ),
        )
        .subcommand(
            Command::new("init")
                .about("Initialise your shell")
                .arg(
                    Arg::new("cmd")
                        .long("cmd")
                        .default_value("gr")
                        .help("Configure the alias that is mapped in your shell environment"),
                )
                .subcommand(Command::new("fish").about("Initialize Fish shell"))
                .subcommand(Command::new("bash").about("Not yet implemented"))
                .subcommand(Command::new("zsh").about("Not yet implemented"))
                .subcommand(Command::new("nushell").about("Initialize nu shell"))
                .subcommand(Command::new("elvish").about("Not yet implemented")),
        );

    let matches = app.clone().get_matches();

    match matches.subcommand() {
        Some(("find", sub_matches)) => {
            let match_type = sub_matches.get_one::<String>("match").unwrap();
            let cwd = env::current_dir()?;
            println!("{}", find_git_dir(&cwd, match_type == "first"));
        }
        Some(("init", sub_matches)) => {
            let cmd = sub_matches.get_one::<String>("cmd").unwrap();
            match sub_matches.subcommand_name() {
                Some("fish") => println!("alias {}=\"cd (gitroot find --match last)\"", cmd),
                Some("nushell") => println!("def --env {} [] {{ cd (gitroot find --match last) }}", cmd),
                Some("bash") | Some("zsh") | Some("elvish") => {
                    return Err("Not yet implemented".into())
                }
                Some(_) => return Err("Unsupported shell specified".into()),
                None => {
                    let mut init_cmd =
                        Command::new("init")
                            .about("Initialise your shell")
                            .arg(Arg::new("cmd").long("cmd").default_value("gr").help(
                                "Configure the alias that is mapped in your shell environment",
                            ))
                            .subcommand(Command::new("fish").about("Initialize Fish shell"))
                            .subcommand(Command::new("bash").about("Not yet implemented"))
                            .subcommand(Command::new("zsh").about("Not yet implemented"))
                            .subcommand(Command::new("nushell").about("Initialize nu shell"))
                            .subcommand(Command::new("elvish").about("Not yet implemented"));
                    init_cmd.print_help()?;
                }
            }
        }
        _ => {
            app.print_help()?;
        }
    }

    Ok(())
}

// find_git_dir function remains unchanged

fn find_git_dir(start_dir: &Path, find_first: bool) -> String {
    let mut match_path: Option<PathBuf> = None;
    let mut current_dir = start_dir.to_path_buf();

    while current_dir.parent().is_some() {
        if let Ok(entries) = fs::read_dir(&current_dir) {
            for entry in entries.flatten() {
                if entry.file_name() == ".git"
                    && entry.file_type().map(|t| t.is_dir()).unwrap_or(false)
                {
                    match_path = Some(current_dir.clone());
                    if find_first {
                        return match_path.unwrap().to_string_lossy().into_owned();
                    }
                }
            }
        }

        if let Some(parent) = current_dir.parent() {
            current_dir = parent.to_path_buf();
        } else {
            break;
        }
    }

    match_path
        .unwrap_or(start_dir.to_path_buf())
        .to_string_lossy()
        .into_owned()
}
