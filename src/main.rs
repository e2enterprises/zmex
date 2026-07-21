extern crate base64;
extern crate clap;
extern crate encrusted_heart;
#[macro_use]
extern crate lazy_static;
extern crate rand;
extern crate regex;

use std::fs::File;
use std::io::prelude::*;
use std::path::{Path, PathBuf};
use std::{io, process};

use clap::{Command, Arg, ArgAction};
use regex::Regex;
use itertools::Itertools;

use encrusted_heart::options::Options;
use encrusted_heart::traits::{BaseOutput, BaseUI};
use encrusted_heart::zmachine::{Zmachine};
// use encrusted_heart::zmachine::{Step, Zmachine};
use encrusted_heart::zscii::ZChar;

const VERSION: &str = env!("CARGO_PKG_VERSION");

lazy_static! {
    static ref ANSI_RE: Regex =
        Regex::new(r"[\x1b\x9b][\[()#;?]*(?:[0-9]{1,4}(?:;[0-9]{0,4})*)?[0-9A-PRZcf-nqry=><]")
            .unwrap();
}

fn main() {
    // https://docs.rs/clap/latest/clap/_tutorial/index.html
    let matches = Command::new("exiled")
        .version(VERSION)
        .about("A zmachine interpreter")
        .arg(Arg::new("debug").long("debug").action(ArgAction::SetTrue))
        .arg(Arg::new("STORY").required(true))
        .arg(Arg::new("INPUT").required(true).action(ArgAction::Append))
        .get_matches();

    let debug = matches.get_flag("debug");
    let story = matches.get_one::<String>("STORY").expect("Story file required.");
    let input = matches.get_many::<String>("INPUT").expect("Game input required.")
        .map(|s| s.as_str())
        .join(" ");

    let story_path = Path::new(story);
    if !story_path.is_file() {
        println!("Couldn't find story file: {}", story_path.to_string_lossy());
        process::exit(1);
    }
    let mut story_file = File::open(story_path).expect("Error opening story file");
    let mut story_data = Vec::new();

    story_file.read_to_end(&mut story_data).expect("Error reading story file");

    let story_version = story_data[0];
    if story_version == 0 || story_version > 8 {
        println!(
            "\n\
             \"{}\" has an unsupported game story_version: {}\n\
             Is this a valid game file?\n",
            story_path.to_string_lossy(),
            story_version
        );
        process::exit(1);
    }

    let ui = BaseUI::new();
    let rand32 = || rand::random();
    let mut opts = Options::default();
    opts.rand_seed = [rand32(), rand32(), rand32(), rand32()];
    opts.dimensions = (80, 24);
    opts.log_instructions = debug;

    let mut zvm = Zmachine::new(story_data, ui, opts);

    // if matches.is_present("continue") {
    //     let save_path = Path::new(matches.value_of("continue").unwrap());
    //     if !save_path.is_file() {
    //         println!(
    //             "\nCouldn't find save file: \n   {}\n",
    //             save_path.to_string_lossy()
    //         );
    //         process::exit(1);
    //     }
    //     let mut save_file = File::open(save_path).expect("Error opening save file");
    //     let mut save_data = Vec::new();
    //     save_file.read_to_end(&mut save_data).expect("Error reading save file");

    //     // restore program counter position, stack frames, and dynamic memory
    //     zvm.restore(&save_data);
    // }

    zvm.step();

    for BaseOutput {
        style: _,
        content: text,
    } in zvm.ui.drain_output() {
        print!("{}", &text);
        io::stdout().flush().unwrap();
        continue;
    }

    if input.chars().count() == 1 {
        zvm.handle_read_char(
            ZChar::from_char(
                input.chars().next().unwrap(), zvm.unicode_table()
            ).unwrap()
        );
    } else {
        zvm.handle_input(input);
    }

    zvm.step();

    for BaseOutput {
        style: _,
        content: text,
    } in zvm.ui.drain_output() {
        print!("{}", &text);
        io::stdout().flush().unwrap();
        continue;
    }

    let save_dir = story_path.parent().unwrap().to_string_lossy().into_owned();
    let save_name = story_path.file_stem().unwrap().to_string_lossy().into_owned();
    let mut save_path = PathBuf::from(&save_dir);
    save_path.push(save_name + "_save.quetzal");

    let mut save_file;
    if let Ok(handle) = File::create(&save_path) {
        save_file = handle;
    } else {
        println!("Error saving file {}", save_path.to_string_lossy());
        process::exit(1);
    }

    // The save PC points to either the save instructions branch data or store
    // data. In either case, this is the last byte of the instruction. (so -1)
    save_file.write_all(zvm.get_save().as_slice())
        .expect("Error saving file");
}
