use encrusted_heart::options::Options;
use encrusted_heart::traits::{BaseOutput, BaseUI};
use encrusted_heart::zmachine::{Step, Zmachine};
use encrusted_heart::zscii::ZChar;

use rustler::{Binary, Env, NifResult, OwnedBinary};

#[rustler::nif(schedule = "DirtyCpu")]
fn process_zmachine_input<'a>(
    env: Env<'a>,
    story_binary: Binary<'a>,
    save_binary: Binary<'a>,
    input: String,
) -> NifResult<(Binary<'a>, String)> {
    let ui = BaseUI::new();
    let rand32 = || rand::random();
    let mut opts = Options::default();
    opts.rand_seed = [rand32(), rand32(), rand32(), rand32()];
    opts.dimensions = (80, 24);

    let mut zvm = Zmachine::new(story_binary.to_vec(), ui, opts);

    if save_binary.len() > 0 {
        zvm.load_savestate(&save_binary);
        // Note: zvm.restore panics here; zvm.load_savestate works instead.
    }

    // First step: Prepare z-machine for input and get input type (char or string)
    match zvm.step() {
        Step::ReadLine => {
            zvm.handle_input(input);
        }
        // Occasionally stories need to read one character of input only and will
        // indicate this with Step::ReadChar; send a single character in this case:
        Step::ReadChar => {
            zvm.handle_read_char(
                ZChar::from_char(
                    if input.chars().count() == 0 {
                        ' '
                    } else {
                        input.chars().next().unwrap()
                    },
                    zvm.unicode_table(),
                )
                .unwrap(),
            );
        }
        Step::Save(_) => {
            panic!("Error: Unexpected ZMachine state - Step::Save")
        }
        Step::Restore => {
            panic!("Error: Unexpected ZMachine state - Step::Restore")
        }
        Step::Done => {
            panic!("Error: Unexpected ZMachine state - Step::Done")
        }
    }

    // Second step: Retrieve z-machine output text as string.
    let mut step = zvm.step();
    let mut output;
    loop {
        output = format_output(zvm.ui.drain_output());
        if output.chars().count() > 0 {
            // loop only until something is printed:
            break;
        } else {
            // if nothing was printed, enter blank input and step zmachine again:
            match step {
                Step::ReadChar => {
                    zvm.handle_read_char(ZChar::from_char(' ', zvm.unicode_table()).unwrap());
                }
                Step::ReadLine => {
                    zvm.handle_input("".to_owned());
                }
                Step::Save(_) => {
                    panic!("Error: Unexpected ZMachine state - Step::Save")
                }
                Step::Restore => {
                    panic!("Error: Unexpected ZMachine state - Step::Restore")
                }
                Step::Done => {
                    panic!("Error: Unexpected ZMachine state - Step::Done")
                }
            }
            step = zvm.step();
        }
    }

    let save_bytes = zvm.get_save();

    // Must convert from OwnedBinary to Binary to return within tuple.
    // See:
    // https://forum.elixirforum.com/t/return-a-binary-tuple-from-a-rust-nif/58528
    // https://docs.rs/rustler/latest/rustler/types/binary/index.html
    let mut owned_binary: OwnedBinary = OwnedBinary::new(save_bytes.len()).unwrap();
    owned_binary.as_mut_slice().copy_from_slice(&save_bytes);
    let save_binary = Binary::from_owned(owned_binary, env);

    Ok((save_binary, output))
}

fn format_output(output: Vec<BaseOutput>) -> String {
    let mut formatted;
    let mut result = String::new();
    let mut interstitial_newline = "";

    // Text formatting:
    // - trim leading and trailing newlines
    // - trim trailing ">" prompt character
    // - separate content strings should always have a single blank line between them
    //   (ie. "interstitial newline")
    for BaseOutput {
        style: _,
        content: text,
    } in output
    {
        formatted = text.trim_end().trim_end_matches(">").trim();

        if formatted.chars().count() > 0 {
            result += interstitial_newline;
            result += formatted;
            result += "\n";
        }

        if interstitial_newline.is_empty() {
            interstitial_newline = "\n";
        }
    }

    result
}

rustler::init!("Elixir.Exzm.EncrustedNif");
