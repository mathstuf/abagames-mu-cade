Mu-cade  readme.txt
for Windows98/2000/XP (OpenGL required)
ver. 0.11
(C) Kenta Cho

物理ムカデ襲来。
爆突くねくねシューティング、Mu-cade。


* 始め方

'mcd0_11.zip'を展開し、'mcd.exe'を実行してください。
ゲームを始めるにはショットキーを押してください。


* 遊び方

自機をフィールドから落ちないように操作し、
敵をフィールド外に叩き落しましょう。

- 操作

o 移動
 方向キー / テンキー / [WASD]   / スティック1 (Axis 1, 2)

o ショット / 方向固定
 [Z][L-Ctrl][R-Ctrl][.]         / トリガ 1, 3, 5, 7, 9, 11
 [IJKL]                         / スティック2 (Axis 3 / 5, 4)

 押しっぱなしでショットが連射され、自機の方向が固定されます。
 旋回しながら撃ちたい場合は、キーを軽く連射してください。

 スティック2で方向を指定して、ショットを撃つこともできます。
 （スティック2の方向に問題がある場合、'-rotatestick2'、'-reversestick2'
   オプションを試してください。例 '-rotatestick2 -90 -reversestick2'）
 （Xbox 360 有線コントローラを使っている場合は、'-enableaxis5'
   オプションを指定してください。）

o しっぽ切り離し
 [X][L-Alt][R-Alt][L-Shift][R-Shift]
 [/][Return][Space]             / トリガ 2, 4, 6, 8, 10, 12

 自機のしっぽを切り離します。
 すべての敵弾が消え、一定時間強力なショットが撃てるようになります。

o ポーズ
 [P]

o ゲーム終了 / タイトルに戻る
 [ESC]

- しっぽ倍率

自機のしっぽは敵を叩き落すごとに長くなり、長さに比例したしっぽ倍率が
得点にかかります。

- エクステンド

自機は50,000点および200,000点ごとに増えます。


* オプション

以下のコマンドラインオプションが利用可能です。

 -brightness n    画面の明るさを設定します (n = 0 - 100, default = 100)
 -res x y         画面サイズを(x, y)に設定します (default = 640, 480)
 -nosound         音を再生しません
 -window          ウィンドウモードで起動します
 -exchange        ショットとしっぽ切り離しキーを入れ替えます
 -rotatestick2 n  スティック2の入力方向をn度回転させます (default = 0)
 -reversestick2   スティック2の入力方向左右反転させます
 -disablestick2   スティック2の入力を無効にします
 -enableaxis5     Axis 5をショットに使い、Axis3をしっぽ切り離しに使います
                  （Xbox 360 有線コントローラ用）

* コメント

ご意見、ご感想は cs8k-cyu@asahi-net.or.jp までお願いします。


* ウェブページ

Mu-cade webpage:
http://www.asahi-net.or.jp/~cs8k-cyu/windows/mcd.html


* 謝辞

Mu-cadeはD言語(ver. 0.149)で記述されています。
 プログラミング言語D
 http://www.kmonos.net/alang/d/

物理エンジンにOpen Dynamics Engineを利用しています。
 Open Dynamics Engine - ODE
 http://www.ode.org/

メディアハンドリングにSimple DirectMedia Layerを利用しています。
 Simple DirectMedia Layer
 http://www.libsdl.org

BGMとSEの再生にSDL_mixerとOgg Vorbis CODECを利用しています。
 SDL_mixer 1.2
 http://www.libsdl.org/projects/SDL_mixer/
 Vorbis.com
 http://www.vorbis.com

D - portingのOpenGL, SDL, SDL_mixer用ヘッダファイルを利用しています。
 D - porting
 http://shinh.skr.jp/d/porting.html

乱数生成にMersenne Twisterを利用しています。
 Mersenne Twister: A random number generator (since 1997/10)
 http://www.math.sci.hiroshima-u.ac.jp/~m-mat/MT/emt.html


* ヒストリ

2006  3/18  ver. 0.11
            Added '-enableaxis5' option. (for xbox 360 wired controller)
            Added '-disablestick2' option.
            Added a spacebar control.
            Adjusted a position of firing shots.
2006  2/25  ver. 0.1
            First released version.


* ライセンス

修正BSDライセンスを適用します。

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
