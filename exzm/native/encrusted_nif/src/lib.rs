use std::sync::Mutex;

use encrusted_heart::options::Options;
use encrusted_heart::traits::{BaseOutput, BaseUI};
use encrusted_heart::zmachine::{Step, Zmachine};
use encrusted_heart::zscii::{ZChar, DEFAULT_UNICODE_TABLE};

use rustler::Resource;
use rustler::{Binary, NifResult, ResourceArc};

// Inner mutex needed to wrap mutable object as NIF resource object.
// See: https://www.erlang.org/doc/apps/erts/erl_nif.html#resource_objects
// Rustler test_resource.rs is the best reference for up-to-date Resource patterns:
// https://github.com/rusterlium/rustler/blob/master/rustler_tests/native/rustler_test/src/test_resource.rs
pub struct ZmachineResource {
    inner: Mutex<Zmachine<BaseUI>>,
}
// ZmachineResource must implement Resource trait from Rustler.
#[rustler::resource_impl]
impl Resource for ZmachineResource {
    // No teardown ops needed currently; add "down" method here if needed in future, eg.
    // https://github.com/rusterlium/rustler/blob/master/rustler_tests/native/rustler_test/src/test_resource.rs#L22
}

#[rustler::nif]
fn generate_zmachine_random_seed() -> NifResult<(i32, i32, i32, i32)> {
    Ok((
        rand::random(),
        rand::random(),
        rand::random(),
        rand::random(),
    ))
}

#[rustler::nif]
fn init_zmachine<'a>(
    story_binary: Binary<'a>,
    save_binary: Binary<'a>,
    seed_a: i32,
    seed_b: i32,
    seed_c: i32,
    seed_d: i32,
) -> ResourceArc<ZmachineResource> {
    let mut opts = Options::default();

    opts.rand_seed = [
        // convert 32-bit signed ints from Elixir to Rust unsigned 32-bit ints:
        (seed_a + i32::MAX) as u32,
        (seed_b + i32::MAX) as u32,
        (seed_c + i32::MAX) as u32,
        (seed_d + i32::MAX) as u32,
    ];

    let mut zmachine = Zmachine::new(story_binary.to_vec(), BaseUI::new(), opts);

    if save_binary.len() > 0 {
        zmachine.load_savestate(&save_binary);
        // Note: zmachine.restore panics here; zmachine.load_savestate works instead.
    }

    ZmachineResource {
        inner: Mutex::new(zmachine),
    }
    .into()
}

#[rustler::nif]
fn step_zmachine(arc: ResourceArc<ZmachineResource>) -> String {
    let mut zmachine = arc.inner.lock().unwrap();

    let step = match zmachine.step() {
        Step::ReadLine => "ReadLine".to_owned(),
        Step::ReadChar => "ReadChar".to_owned(),
        Step::Save(_) => "Save".to_owned(),
        Step::Restore => "Restore".to_owned(),
        Step::Done => "Done".to_owned(),
    };

    step
}

#[rustler::nif]
fn send_line_to_zmachine(arc: ResourceArc<ZmachineResource>, input: String) -> NifResult<()> {
    let mut zmachine = arc.inner.lock().unwrap();

    zmachine.handle_input(input);

    Ok(())
}

#[rustler::nif]
fn send_char_to_zmachine(arc: ResourceArc<ZmachineResource>, input: String) -> NifResult<()> {
    let mut zmachine = arc.inner.lock().unwrap();

    zmachine.handle_read_char(
        ZChar::from_char(
            if input.chars().count() == 0 {
                ' ' // If there is no input, just send a blank string.
            } else {
                input.chars().next().unwrap()
            },
            DEFAULT_UNICODE_TABLE,
        )
        .unwrap(),
    );

    Ok(())
}

#[rustler::nif]
fn drain_zmachine_output(arc: ResourceArc<ZmachineResource>) -> String {
    let mut zmachine = arc.inner.lock().unwrap();
    let mut output = String::new();

    for BaseOutput { style: _, content } in zmachine.ui.drain_output() {
        output.push_str(&content);
    }

    output
}

#[rustler::nif]
fn save_zmachine_state(arc: ResourceArc<ZmachineResource>) -> Vec<u8> {
    let zmachine = arc.inner.lock().unwrap();
    let save_binary = zmachine.get_save();

    save_binary
    // Note: Return a Vec<u8> here for simplicity (this is what zmachine.get_save()
    // naturally returns). This necessitates a :binary.list_to_bin(save) call on the
    // Elixir side to convert from a list of integers to an actual Elixir binary.
    //
    // Alternative would be to covert the .get_save() result to an OwnedBinary then
    // convert _that_ into a Binary<'a> as described below for posterity. We'll avoid
    // that here to keep as much logic out of the Rust side as possible for
    // NIF-performance reasons.
    //
    // Returning a Binary as part of a Tuple from a NIF
    // ------------------------------------------------
    // Must convert from OwnedBinary to Binary to return within tuple. References:
    // https://forum.elixirforum.com/t/return-a-binary-tuple-from-a-rust-nif/58528
    // https://docs.rs/rustler/latest/rustler/types/binary/index.html
    //
    // use rustler::{Binary, Env, NifResult, OwnedBinary};
    //
    // fn save_zmachine_state(
    //     env: Env<'a>,
    //     arc: ResourceArc<ZmachineResource>,
    // } -> NifResult<( Binary<'a>, ...other values...)> {
    //     let zmachine = arc.inner.lock().unwrap();
    //     let save_binary = zmachine.get_save()
    //
    //     OwnedBinary::new(save_bytes.len()).unwrap();
    //     owned_binary.as_mut_slice().copy_from_slice(&save_bytes);
    //     let save_binary = Binary::from_owned(owned_binary, env);
    //
    //     Ok((save_binary, ...other values...))
    // }
}

rustler::init!("Elixir.Exzm.EncrustedNif");
