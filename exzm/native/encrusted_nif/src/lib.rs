use encrusted_heart::options::Options;
use encrusted_heart::traits::{BaseOutput, BaseUI};
use encrusted_heart::zmachine::{Step, Zmachine};
use encrusted_heart::zscii::ZChar;

use rustler::{Binary, Env, NifResult, OwnedBinary};

#[rustler::nif(schedule = "DirtyCpu")]
fn prime_zmachine<'a>(
    story_binary: Binary<'a>,
    save_binary: Binary<'a>,
    seed: bool,
    seed_a: i32,
    seed_b: i32,
    seed_c: i32,
    seed_d: i32,
) -> NifResult<(String, i32, i32, i32, i32)> {
    let mut opts = Options::default();

    let mut seed_a_i32: i32 = seed_a;
    let mut seed_b_i32: i32 = seed_b;
    let mut seed_c_i32: i32 = seed_c;
    let mut seed_d_i32: i32 = seed_d;

    if seed {
        let seed_a_u32: u32 = (seed_a_i32 + i32::MAX) as u32;
        let seed_b_u32: u32 = (seed_b_i32 + i32::MAX) as u32;
        let seed_c_u32: u32 = (seed_c_i32 + i32::MAX) as u32;
        let seed_d_u32: u32 = (seed_d_i32 + i32::MAX) as u32;
        opts.rand_seed = [seed_a_u32, seed_b_u32, seed_c_u32, seed_d_u32];
    } else {
        opts.rand_seed = [rand::random(), rand::random(), rand::random(), rand::random()];
        seed_a_i32 = (opts.rand_seed[0] - i32::MAX as u32) as i32;
        seed_b_i32 = (opts.rand_seed[1] - i32::MAX as u32) as i32;
        seed_c_i32 = (opts.rand_seed[2] - i32::MAX as u32) as i32;
        seed_d_i32 = (opts.rand_seed[3] - i32::MAX as u32) as i32;
    }

    let mut zvm = Zmachine::new(story_binary.to_vec(), BaseUI::new(), opts);

    if save_binary.len() > 0 {
        zvm.load_savestate(&save_binary);
        // Note: zvm.restore panics here; zvm.load_savestate works instead.
    }

    let step = match zvm.step() {
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

    Ok((step, seed_a_i32, seed_b_i32, seed_c_i32, seed_d_i32))
}

#[rustler::nif(schedule = "DirtyCpu")]
fn send_line_to_zmachine<'a>(
    env: Env<'a>,
    story_binary: Binary<'a>,
    save_binary: Binary<'a>,
    input: String,
    seed: bool,
    seed_a: i32,
    seed_b: i32,
    seed_c: i32,
    seed_d: i32,
) -> NifResult<(Binary<'a>, String, i32, i32, i32, i32)> {
    let mut opts = Options::default();

    let mut seed_a_i32: i32 = seed_a;
    let mut seed_b_i32: i32 = seed_b;
    let mut seed_c_i32: i32 = seed_c;
    let mut seed_d_i32: i32 = seed_d;

    if seed {
        let seed_a_u32: u32 = (seed_a_i32 + i32::MAX) as u32;
        let seed_b_u32: u32 = (seed_b_i32 + i32::MAX) as u32;
        let seed_c_u32: u32 = (seed_c_i32 + i32::MAX) as u32;
        let seed_d_u32: u32 = (seed_d_i32 + i32::MAX) as u32;
        opts.rand_seed = [seed_a_u32, seed_b_u32, seed_c_u32, seed_d_u32];
    } else {
        opts.rand_seed = [rand::random(), rand::random(), rand::random(), rand::random()];
        seed_a_i32 = (opts.rand_seed[0] - i32::MAX as u32) as i32;
        seed_b_i32 = (opts.rand_seed[1] - i32::MAX as u32) as i32;
        seed_c_i32 = (opts.rand_seed[2] - i32::MAX as u32) as i32;
        seed_d_i32 = (opts.rand_seed[3] - i32::MAX as u32) as i32;
    }

    let mut zvm = Zmachine::new(story_binary.to_vec(), BaseUI::new(), opts);

    if save_binary.len() > 0 {
        zvm.load_savestate(&save_binary);
        // Note: zvm.restore panics here; zvm.load_savestate works instead.
    }

    // No matter where save occurred, always need to step before sending input to zvm:
    zvm.step();

    zvm.handle_input(input);

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

    Ok((save_binary, output, seed_a_i32, seed_b_i32, seed_c_i32, seed_d_i32))
}

#[rustler::nif(schedule = "DirtyCpu")]
fn send_char_to_zmachine<'a>(
    env: Env<'a>,
    story_binary: Binary<'a>,
    save_binary: Binary<'a>,
    input: String,
    seed: bool,
    seed_a: i32,
    seed_b: i32,
    seed_c: i32,
    seed_d: i32,
) -> NifResult<(Binary<'a>, String, i32, i32, i32, i32)> {
    let mut opts = Options::default();

    let mut seed_a_i32: i32 = seed_a;
    let mut seed_b_i32: i32 = seed_b;
    let mut seed_c_i32: i32 = seed_c;
    let mut seed_d_i32: i32 = seed_d;

    if seed {
        let seed_a_u32: u32 = (seed_a_i32 + i32::MAX) as u32;
        let seed_b_u32: u32 = (seed_b_i32 + i32::MAX) as u32;
        let seed_c_u32: u32 = (seed_c_i32 + i32::MAX) as u32;
        let seed_d_u32: u32 = (seed_d_i32 + i32::MAX) as u32;
        opts.rand_seed = [seed_a_u32, seed_b_u32, seed_c_u32, seed_d_u32];
    } else {
        opts.rand_seed = [rand::random(), rand::random(), rand::random(), rand::random()];
        seed_a_i32 = (opts.rand_seed[0] - i32::MAX as u32) as i32;
        seed_b_i32 = (opts.rand_seed[1] - i32::MAX as u32) as i32;
        seed_c_i32 = (opts.rand_seed[2] - i32::MAX as u32) as i32;
        seed_d_i32 = (opts.rand_seed[3] - i32::MAX as u32) as i32;
    }

    let mut zvm = Zmachine::new(story_binary.to_vec(), BaseUI::new(), opts);

    if save_binary.len() > 0 {
        zvm.load_savestate(&save_binary);
        // Note: zvm.restore panics here; zvm.load_savestate works instead.
    }

    // No matter where save occurred, always need to step before sending input to zvm:
    zvm.step();

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

    Ok((save_binary, output, seed_a_i32, seed_b_i32, seed_c_i32, seed_d_i32))
}

rustler::init!("Elixir.Exzm.EncrustedNif");
