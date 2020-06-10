Free Pascal bindings for Delta Chat and Lazarus Delta Chat client
=================================================================

To build, compile https://github.com/deltachat/deltachat-core-rust/
with `cargo build --release` and copy `target/release/libdeltachat.a`
to the root of this repository.

To build the client, run `lazbuild deltachat.lpr`. Then run `deltachat`
binary and point it to the database file.

License
-------
Bindings (`hDeltachat.pp`) are released under the terms of
deltachat-core-rust, that is Mozilla Pubilc License 2.0.

Lazarus client is released under the terms of the GNU General Public
License as published by the Free Software Foundation, either version 3
of the License, or (at your option) any later version.
