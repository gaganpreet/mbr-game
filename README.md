# About
A simplified pacman clone I wrote a while ago in assembly, to be run as an MBR. Originally written for the [Stripe MBR challenge](https://stripe.com/jobs#engineer):

    Submit a 512-byte MBR boot sector that does something interesting (the specifics are up to you) and before exiting prints "Stripe".

The easiest way to run is:

    nasm mbr-game.asm
    qemu-system-i386 mbr-game

Overall, this is all written in 482 bytes, including the bytes required for MBR. I wanted to add at least one enemy, but 30 bytes weren't enough for one.

The code isn't heavily commented, especially for a beginner, but routine names should make the functionality fairly obvious. If you are interested in learning, start here:

    http://wiki.osdev.org/MBR_%28x86%29
    http://blog.markloiseau.com/2012/05/hello-world-mbr-tutorial/
    https://en.wikibooks.org/wiki/X86_Assembly

# Screenshot
![Screenshot](https://raw.github.com/gaganpreet/mbr-game/master/screenshot.png)
