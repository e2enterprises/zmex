use std::sync::Mutex;

use encrusted_heart::options::Options;
use encrusted_heart::traits::{BaseOutput, BaseUI};
use encrusted_heart::zmachine::{Step, Zmachine};
use encrusted_heart::zscii::{ZChar, DEFAULT_UNICODE_TABLE};

use rustler::Resource;
use rustler::{Binary, NifResult, ResourceArc};

// pub struct ZmachineResourceInner {
//     zmachine: Zmachine<BaseUI>
// }

pub struct ZmachineResource {
    inner: Mutex<Zmachine<BaseUI>>,
}

#[rustler::resource_impl]
impl Resource for ZmachineResource {}

#[rustler::nif]
fn init_zmachine_seed() -> NifResult<(i32, i32, i32, i32)> {
    Ok((rand::random(), rand::random(), rand::random(), rand::random()))
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

    ZmachineResource { inner: Mutex::new(zmachine) }.into()
}

#[rustler::nif]
fn prime_zmachine_for_input(arc: ResourceArc<ZmachineResource>) -> String {
    let mut zmachine = arc.inner.lock().unwrap();

    let step = match zmachine.step() {
        Step::ReadLine => { "ReadLine".to_owned() }
        Step::ReadChar => { "ReadChar".to_owned() }
        Step::Save(_) => {
            panic!("unexpected ZMachine step (Save)")
        }
        Step::Restore => {
            panic!("unexpected ZMachine step (Restore)")
        }
        Step::Done => {
            panic!("unexpected ZMachine step (Done)")
        }
    };

    step
}

#[rustler::nif]
fn send_line_to_zmachine(arc: ResourceArc<ZmachineResource>, input: String) -> String {
    let mut zmachine = arc.inner.lock().unwrap();

    zmachine.handle_input(input);
    zmachine.step();

    let mut output = String::new();
    for BaseOutput {
        style: _,
        content,
    } in zmachine.ui.drain_output()
    {
        output.push_str(&content);
    }

    output
}

#[rustler::nif]
fn send_char_to_zmachine(arc: ResourceArc<ZmachineResource>, input: String) -> String {
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

    zmachine.step();

    let mut output = String::new();
    for BaseOutput {
        style: _,
        content,
    } in zmachine.ui.drain_output()
    {
        output.push_str(&content);
    }

    output
}

#[rustler::nif]
fn save_zmachine_state(arc: ResourceArc<ZmachineResource>) -> Vec<u8> {
    let zmachine = arc.inner.lock().unwrap();
    zmachine.get_save()
}
// Note:
// Must convert from OwnedBinary to Binary to return within tuple. References:
// https://forum.elixirforum.com/t/return-a-binary-tuple-from-a-rust-nif/58528
// https://docs.rs/rustler/latest/rustler/types/binary/index.html
//
// use rustler::{Binary, Env, Term, NifResult, OwnedBinary};
//
// OwnedBinary::new(save_bytes.len()).unwrap();
// owned_binary.as_mut_slice().copy_from_slice(&save_bytes);
// let save_binary = Binary::from_owned(owned_binary, env);
//
// Ok((save_binary, ...other values...))
//
// (Return type -> NifResult<(Binary<'a>, String, i32, ...etc...)>)

rustler::init!("Elixir.Exzm.EncrustedNif");
