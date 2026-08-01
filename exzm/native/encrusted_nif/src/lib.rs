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
    let mut opts = Options::default();
    opts.rand_seed = [rand::random(), rand::random(), rand::random(), rand::random()];

    let mut zvm = Zmachine::new(story_binary.to_vec(), BaseUI::new(), opts);

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
                        ' ' // If there is no input, just send a blank string.
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
    zvm.step();

    let mut output = String::new();
    for BaseOutput {
        style: _,
        content,
    } in zvm.ui.drain_output()
    {
        output.push_str(&content);
    }

    let save_bytes = zvm.get_save();

    // Must convert from OwnedBinary to Binary to return within tuple. References:
    // https://forum.elixirforum.com/t/return-a-binary-tuple-from-a-rust-nif/58528
    // https://docs.rs/rustler/latest/rustler/types/binary/index.html
    let mut owned_binary: OwnedBinary = OwnedBinary::new(save_bytes.len()).unwrap();
    owned_binary.as_mut_slice().copy_from_slice(&save_bytes);
    let save_binary = Binary::from_owned(owned_binary, env);

    Ok((save_binary, output))
}

rustler::init!("Elixir.Exzm.EncrustedNif");
