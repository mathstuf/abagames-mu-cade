Mu-cade  readme.txt
for Windows98/2000/XP (OpenGL required)
ver. 0.11
(C) Kenta Cho

The Physics Centipede Invasion.
Smashup waggly shmup, 'Mu-cade'.


* How to start

Unpack mcd0_11.zip, and run 'mcd.exe'.
Press a shot key to start a game.


* How to play

Keep your ship from falling down and push enemies out of the way.

- Controls

o Move
 Arrow / Num / [WASD]           / Stick1 (Axis 1, 2)

o Fire shots / Hold direction
 [Z][L-Ctrl][R-Ctrl][.]         / Trigger 1, 3, 5, 7, 9, 11
 [IJKL]                         / Stick2 (Axis 3 or 5, 4)

 Hold a key to open automatic fire and hold the direction of a ship.
 Tap a key to take a turn while firing.

 You can also fire shots with the second stick.
 (If you have a problem with the direction of the stick2, try
  '-rotatestick2' and '-reversestick2' options.
  e.g. '-rotatestick2 -90 -reversestick2')
 (If you are using xbox 360 wired controller, use
  '-enableaxis5' option.)

o Cut off the tail
 [X][L-Alt][R-Alt][L-Shift][R-Shift]
 [/][Return][Space]             / Trigger 2, 4, 6, 8, 10, 12

 Cut off the tail of your ship. This action also wipes out all bullets and
 you obtain powerful shots for a while.

o Pause
 [P]

o Exit / Return to the title
 [ESC]

- Tail multiplier

The tail of your ship becomes longer when you push an enemy out and
you get a score multiplier.

- Extra ship

You earn an extra ship 50,000 and every 200,000 points.


* Options

These command-line options are available:

 -brightness n    Set the brightness of the screen. (n = 0 - 100, default = 100)
 -res x y         Set the screen resolution to (x, y). (default = 640, 480)
 -nosound         Stop the sound.
 -window          Launch the game in the window, not use the full-screen.
 -exchange        Exchange a shot key and a cut off key.
 -rotatestick2 n  Rotate the direction of the stick2 in n degrees.
 -reversestick2   Reverse the direction of the stick2.
 -disablestick2   Disable the input of the stick2.
 -enableaxis5     Use the input of axis 5 to fire shots and
                  axis 3 to cut off the tail.
                  (for xbox 360 wired controller)


* Comments

If you have any comments, please mail to cs8k-cyu@asahi-net.or.jp


* Webpage

Mu-cade webpage:
http://www.asahi-net.or.jp/~cs8k-cyu/windows/mcd_e.html


* Acknowledgement

Mu-cade is written in the D Programming Language(ver. 0.149).
 D Programming Language
 http://www.digitalmars.com/d/index.html

Open Dynamics Engine is used for the physics.
 Open Dynamics Engine - ODE
 http://www.ode.org/

Simple DirectMedia Layer is used for media handling.
 Simple DirectMedia Layer
 http://www.libsdl.org/

SDL_mixer and Ogg Vorbis CODEC are used for playing BGMs/SEs.
 SDL_mixer 1.2
 http://www.libsdl.org/projects/SDL_mixer/
 Vorbis.com
 http://www.vorbis.com/

D Header files at D - porting are for use with OpenGL, SDL and SDL_mixer.
 D - porting
 http://shinh.skr.jp/d/porting.html

Mersenne Twister is used for creating a random number.
 Mersenne Twister: A random number generator (since 1997/10)
 http://www.math.sci.hiroshima-u.ac.jp/~m-mat/MT/emt.html


* History

2006  3/18  ver. 0.11
            Added '-enableaxis5' option. (for xbox 360 wired controller)
            Added '-disablestick2' option.
            Added a spacebar control.
            Adjusted a position of firing shots.
2006  2/25  ver. 0.1
            First released version.


* License

License
-------

Copyright 2006 Kenta Cho. All rights reserved.

Redistribution and use in source and binary forms,
with or without modification, are permitted provided that
the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice,
    this list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
    this list of conditions and the following disclaimer in the documentation
    and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
THE REGENTS OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
