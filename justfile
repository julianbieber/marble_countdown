# Set the default shell to bash
set shell := ["bash", "-c"]

# Default recipe to show available commands
default:
    @just --list

build:
    cargo build --release

run:
    cargo run --release

