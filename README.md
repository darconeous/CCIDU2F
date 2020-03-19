SmartCard U2F Adapter for macOS
===============================

This is a tool for using FIDO U2F applets on smart cards and NFC
tokens as if they were first-class U2F HID devices on macOS. You would
use this if you want to, say, pair your NFC-only U2F token with your
Google account (Google won't let you set up security tokens on your
phone for some reason). It's also particularly useful if you are
developing a U2F token on a smart card.

This program was a quick hack to get my own tokens paired to my Google
account, but I figured others might find it useful. At the moment it
isn't pretty and it isn't easy-to-install, either. If you read the
code, keep in mind I haven't written Objective-C code in about 7
years, so I was a little rusty. But hey, it works. Forks and pull
requests are welcome.

This project is based on [SoftU2F](https://github.com/github/SoftU2F).
Without that project, this project would not exist. All hail SoftU2F.

## Limitations ##

 * Only handles one U2F smart card at a time.
 * Only supports tokens that can speak U2F/CTAP1. CTAP2-only tokens
   are not supported.
 * Only supports the U2F flow. If you are using a CTAP1/CTAP2 token,
   you will only be able to use CTAP1 features.

## Requirements ##

It might go without saying, but in order to use this project you are
going to need a smart card reader or some USB device that looks like a
smart card reader to the computer (like an ACR122U, if you are doing
NFC stuff). And a Mac.

## Building ##

Build it in Xcode.

## Installing ##

First, install [SoftU2F](https://github.com/github/SoftU2F#installing).

Then neuter the launch agent:

    launchctl unload -w ~/Library/LaunchAgents/com.github.SoftU2F.plist

You can now run `CCIDU2F`.

## Running ##

Run it from Xcode. I said this was a hack, right?

## Usage ##

Once `CCIDU2F` is running in the background it is totally
plug-and-play. When prompted to insert your U2F token, insert it or
bring it toward the reader. It should "Just Work", no matter
what browser you are using.

Note that 25% of registration requests will fail. This is a known bug
in Apple's FIDO2 implementation. See [this article](https://medium.com/@darconeous/thoughts-on-apples-fido2-support-44a2aadcf093)
for more info.

