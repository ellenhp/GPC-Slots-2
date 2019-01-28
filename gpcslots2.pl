#!/usr/bin/perl
#GPCSLOTS 2
#  By The Entity Known As MikeeUSA

#This program is free software; you can redistribute it and/or
#modify it under the terms of the GNU General Public License
#as published by the Free Software Foundation; either version 2
#of the License, or (at your option) any later version.
#
#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.
#
#You should have received a copy of the GNU General Public License
#along with this program; if not, write to the Free Software
#Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

package PrintWrapper;
use IO::Handle;
use strict;
use warnings;
#################################################################################
##Awsome terminal voodoo below by Div0. This allows the terminal output to be
## split into two parts: a forground (payout lists)
## and a background (slot machine reels) for use with Multi Layer LCDs
## (like the PureDepth(TM) displays found on IGT(TM) ReelDepth(TM) slotmachines.
my $SEP = "\377";
sub PUSHED
{
	my ($class, $mode, $fh) = @_;
	return bless {
		linebuf => ''
	}, $class;
}
sub println
{
	my ($self, $l, $fh) = @_;
	my ($l_left, $l_right, $e_left, $e_right, $side, $cnt) = ('', '', '', '', 0, 0);
	die "WTF" if $SEP eq "";
	while($l =~ s/^(\007|\033\[.*?[A-Za-z])|($SEP)|(.)//)
	{
		if(defined $1) # escape sequence
		{
			if($side)
			{
				$e_left .= $1;
				$l_right .= $1;
			}
			else
			{
				$l_left .= $1;
				$e_right .= $1;
			}
		}
		elsif(defined $2) # toggle
		{
			$side = !$side;
			if($side)
			{
				$l_right .= $e_right;
				#$e_right = '';
			}
			else
			{
				$l_left .= $e_left;
				#$e_left = '';
			}
		}
		elsif(defined $3) # text
		{
			if($side)
			{
				$l_left .= "\033[107m ";
				$l_right .= $3;
			}
			else
			{
				$l_left .= $3;
				$l_right .= "\033[107m ";
			}
			++$cnt;
		}
	}
	my $sep = ' ' x (80 - $cnt);
	print $fh "$l_left\033[m$sep$l_right$sep\033[m";
}
sub aflush
{
	my ($self, $fh) = @_;
	while($self->{linebuf} =~ s/^(.*?)([\r\n])//)
	{
		my $l = $1;
		my $s = $2;
		$self->println($l, $fh);
		print $fh $s;
		$fh->flush();
	}
}
sub WRITE
{
	my ($self, $buf, $fh) = @_;
	if(!defined $self->{linebuf})
	{
		if($buf =~ s/^([^\r\n]*([\r\n])?)//)
		{
			$self->{linebuf} = ''
				if $2;
			print $fh $buf;
			$fh->flush();
		}
		return;
	}
	$self->{linebuf} .= $buf;
	$self->aflush($fh);
}
sub FLUSH
{
	my ($self, $fh) = @_;
	$self->aflush($fh);
	if(length $self->{linebuf})
	{
		print $fh $self->{linebuf};
		$self->{linebuf} = undef;
		$fh->flush();
	}
}
##Awsome terminal voodoo above by Div0. This allows the terminal output to be
## split into two parts: a forground (payout lists)
## and a background (slot machine reels) for use with Multi Layer LCDs
## (like the PureDepth(TM) displays found on IGT(TM) ReelDepth(TM) slotmachines.
#################################################################################

no strict;
no warnings;

package main;
use Term::ANSIColor;
use POSIX qw(ceil);
use POSIX qw(floor);
use IO::Handle;
print color 'reset';

$compatVT100 = 1;   ##Enable VT100 Features:  1 = Yes 0 = No
$compatUNIXY = 1;   ##Enable *NIX Features:   1 = Yes 0 = No
$compatANSI = 1;    ##Enable ANSI Color:      1 = Yes 0 = No
$animate = 1;       ##Enable Animation:       1 = Yes 0 = No
$anispeed = 1;      ##Speed of Animation      1 = 1X  2 = 2X  3 = 3X
$soundfx = 1;       ##Enable (Beep) SoundFX:  1 = Yes 0 = No
$music = 0;         ##Enable Music:           1 = Yes 0 = No
$playtrack = 1;     ##Enable Play Tracker     1 = Yes 0 = No
$htmlgraphnums = 1; ##Have Graph Values       1 = Yes 0 = No
                    ## printed Under Bargraph

##To Disable Color ANSI on Windows(R) Uncomment the Following 5 Lines##
#sub colored {
#	my ($string, @codes);
#	$string = shift;
#	return $string;
#}
##To Disable Color ANSI on Windows(R) Uncomment the Above 5 Lines##

#------------------#
# Music Setup      # 
#------------------#

$musicdir = '~/.gpcslots2/midi/';
	#*Searches for the files in this directory
@musicfiles = ('kc_32x_11.mid','s1_sg_11.mid','s3db_sg_19.mid','s3_sg_12.mid','s3_sg_31.mid','sa_gba_11.mid','scd_mcd_18.mid');
	#*These are file names of the midi files I use on my system.
	#*   They were sequenced by John Weeks (espiokaos.com).
	#*I am looking for similar quality opensource(GPL,BSD,Debian Compatable Licensed)
	#*   or public domain midis to bundle with this game.
	#*Replace the array entries with songs you personally like. Jazzy Casino Music.
@rrmusicfiles = ('onthemar.mid','czardas1.mid','tomnaya.mid');
	#*These are file names of the midi files I use on my system for russian roulette. Russian Folk and Russian 19th Century Music.
@bankmusicfiles = ('gp_v01.mid','gp_v02.mid','gp_v03.mid','gp_v04.mid','gp_v05.mid','gp_v06.mid','gp_v07.mid','gp_v08.mid','gp_v09.mid','gp_v10.mid','gp_v11.mid','gp_v12.mid');
	#*These are file names of the midi files I use on my system for the bank. Classical Music (Vivaldi etc).	
$musicplayer = 'timidity';
	#*Midis sound great with freepats (http://freepats.opensrc.org) by Eric A. Welsh 
$musicvolume = '5';
	#*Set as to keep the songs as nice background music and as not to drown out the
	#*   terminal beep soundfx.
$rrmusicvolume = '20';
	#*Set abit higher as this is a diffrent type of music
$bankmusicvolume = '15';
	#*Classical Background music for the bank.	
$musicvolumecmd = '--volume=';
$musictermquiet = '> /dev/null';
	#* Redirect terminal noise (should be > /dev/null)
#------------------#
# Code Begins Here # 
#------------------#

sub help {
			print"Animation Speed  :  1/$anispeed"; print"X     ANSI Color       :  $compatANSI\n";
			print"Animation        :  $animate";  print"        Music            :  $music\n";
			print"UNIX Features    :  $compatUNIXY"; print"        Terminal SoundFX :  $soundfx\n";
			print"VT100 Features   :  $compatVT100\n";
			print"Playtracking     :  $playtrack\n";
			print'-h,   --help                  Display this help screen'; print"\n";
			print'-k,   --keys                  Display keyboard commands information'; print"\n";
			print'-nan, --no-ansi               Turn ANSI color off'; print"\n";
			print'-an,  --ansi                  Turn ANSI color on (Default)'; print"\n";
			print'-na,  --no-animation          Turn all animations off'; print"\n";
			print'-a,   --animation             Turn all animations on (Default)'; print"\n";
			print'-nt,  --no-vt100              Turn vt100 support off'; print"\n";
			print'-t,   --vt100                 Turn vt100 support on (Default)'; print"\n";
			print'-nu,  --no-unix               Turn unix specific code off'; print"\n";
			print'-u,   --unix                  Turn unix specific code on (Default)'; print"\n";
			print'-nsfx,--no-soundfx            Turn terminal (beep) soundfx off'; print"\n";
			print'-sfx, --sounfx                Turn terminal (beep) soundfx on (Default)'; print"\n";
			print'-nm,  --no-music              Turn music off (Default)'; print"\n";
			print'-m,   --music                 Turn music on'; print"\n";
			print'-npt, --no-playtracking      Turn playtracking off (Default)'; print"\n";
			print'-pt,  --playtracking         Turn playtracking on (used for html graph)'; print"\n";
			print'-as1, --animation-speed-1     Set animation speed to 1/1X (Default)'; print"\n";
			print'-as2, --animation-speed-2     Set animation speed to 1/2X'; print"\n";
			print'-as3, --animation-speed-3     Set animation speed to 1/3X'; print"\n";
			print'      --name                  Change casino title name(not available in-game)'; print"\n";
			print'      --gnome-terminal        Open in gnome-terminal(not available in-game)'; print"\n";
			print'                              (Ex: gpcslots2 --gnome-terminal -m -nsfx )'; print"\n";
			print'      --konsole               Open in konsole(not available in-game)'; print"\n";
			print'                              (Ex: gpcslots2 --konsole -m -nsfx )'; print"\n";
}

sub helpkeys {
			print'P             On Slotmachines: Enters a token or tokens and spins the reels'; print"\n";
			print'              On Table Games: Rolls the dice or spins the roulette wheel'; print"\n";
			print'              On Status Printout Machine: Prints game stats to a html file'; print"\n";
			print'            Meaning: Play'; print"\n";
			print'1P            On Slotmachines: Enters a token or tokens and spins the reels'; print"\n";
			print'            Meaning: Play One'; print"\n";
			print'2P,3P...8P    On Slotmachines: Enters tokens, selects multiple play lines,'; print"\n"; 
			print'                               and then spins the reels'; print"\n";
			print'            Meaning: Play Two, Play Three...Play Eight'; print"\n";
			print"\n";
			print'A             On Slotmachines: Executes the last entered valid command'; print"\n";
			print'              On Table Games: Rolls the dice or spins the roulette wheel'; print"\n";
			print'            Meaning: Again'; print"\n";
			print'B             On Table Games: Set your bet'; print"\n";
			print'            Meaning: Bet'; print"\n";
			print'C             On Slotmachines: Returns to casino menu'; print"\n";
			print'              On Table Games: Returns to casino menu'; print"\n";
			print'              On Status Printout Machine: Returns to casino menu'; print"\n";
			print'            Meaning: Casino Menu'; print"\n";
			print'EXIT          On Slotmachines: Quits game'; print"\n";
			print'              On Table Games: Quits game'; print"\n";
			print'              On Status Printout Machine: Quits game'; print"\n";
			print'              On Casino Menu: Quits game'; print"\n";
			print'            Meaning: Exit game'; print"\n";
			print'N             On Table Games: Select numbers to bet on'; print"\n";
			print'            Meaning: Numbers'; print"\n";
			print"\n";
			print'1,2,3...10    On Casino Menu: Selects and enters a subgame'; print"\n";
			print'            Meaning: Select Game One, Two, Three... Ten'; print"\n";
}

BEGIN {
	if (@ARGV[0] eq '--gnome-terminal') {
		$buff0 = '';
		foreach(@ARGV) {
			if (($_ ne '--gnome-terminal') and ($_ ne '--konsole')) {
				$buff0 = "$buff0"." $_";
			}
		}
		exec("gnome-terminal --hide-menubar --title=GPC-Slots2 --geometry=80x30 -x perl $0 $buff0");
	} elsif (@ARGV[0] eq '--konsole') {
		$buff0 = '';
		foreach(@ARGV) {
			if (($_ ne '--konsole') and ($_ ne '--gnome-terminal')) {
				$buff0 = "$buff0"." $_";
			}
		}
		exec("konsole --noresize --nohist --noscrollbar --notabbar --notoolbar --nomenubar --nohist --noframe --vt_sz 80x30 --T=GPC-Slots2 -e perl $0 $buff0");
	} else {
		foreach(@ARGV) {
			if (($_ eq '-h') or ($_ eq '-help') or ($_ eq '--help')) {
			print'GPCSLOTS 2'; print"\n";
			print' By The Entity Known As MikeeUSA'; print"\n";
			print"\n";
			print'This program is free software; you can redistribute it and/or'; print"\n";
			print'modify it under the terms of the GNU General Public License'; print"\n";
			print'as published by the Free Software Foundation; either version 2'; print"\n";
			print'of the License, or (at your option) any later version.'; print"\n";
			print"\n";
			print'This program is distributed in the hope that it will be useful,'; print"\n";
			print'but WITHOUT ANY WARRANTY; without even the implied warranty of'; print"\n";
			print'MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the'; print"\n";
			print'GNU General Public License for more details.'; print"\n";
			print"\n";
			print'You should have received a copy of the GNU General Public License'; print"\n";
			print'along with this program; if not, write to the Free Software'; print"\n";
			print'Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.'; print"\n";
			print"\n";
			print'WWW: https://cat2.dynu.ca    '; print"\n";
			print'IRC: cat2.dynu.ca  #linux    '; print"\n\n";
			print'Usage: gpcslots2 [options]'; print"\n";
   			print'Where [options] are any of:'; print"\n";
			print'-h,   --help                  Display this help screen'; print"\n";
			print'-k,   --keys                  Display keyboard commands information'; print"\n";
			print'-nan, --no-ansi               Turn ANSI color off'; print"\n";
			print'-an,  --ansi                  Turn ANSI color on (Default)'; print"\n";
			print'-na,  --no-animation          Turn all animations off'; print"\n";
			print'-a,   --animation             Turn all animations on (Default)'; print"\n";
			print'-nt,  --no-vt100              Turn vt100 support off'; print"\n";
			print'-t,   --vt100                 Turn vt100 support on (Default)'; print"\n";
			print'-nu,  --no-unix               Turn unix specific code off'; print"\n";
			print'-u,   --unix                  Turn unix specific code on (Default)'; print"\n";
			print'-nsfx,--no-soundfx            Turn terminal (beep) soundfx off'; print"\n";
			print'-sfx, --sounfx                Turn terminal (beep) soundfx on (Default)'; print"\n";
			print'-nm,  --no-music              Turn music off (Default)'; print"\n";
			print'-m,   --music                 Turn music on'; print"\n";
			print'-npt, --no-playtracking      Turn playtracking off (Default)'; print"\n";
			print'-pt,  --playtracking         Turn playtracking on (used for html graph)'; print"\n";
			print'-as1, --animation-speed-1     Set animation speed to 1/1X (Default)'; print"\n";
			print'-as2, --animation-speed-2     Set animation speed to 1/2X'; print"\n";
			print'-as3, --animation-speed-3     Set animation speed to 1/3X'; print"\n";
			print'      --name                  Change casino title name(not available in-game)'; print"\n";
			print'      --gnome-terminal        Open in gnome-terminal(not available in-game)'; print"\n";
			print'                              (Ex: gpcslots2 --gnome-terminal -m -nsfx )'; print"\n";
			print'      --konsole               Open in konsole(not available in-game)'; print"\n";
			print'                              (Ex: gpcslots2 --konsole -m -nsfx )'; print"\n";
			print'      --dual                  Seperate output of forground and background'; print"\n";
			print'                              for use with Multi-Layer LCDs (not available in-game)'; print"\n";

			exit();
			} elsif (($_ eq '-k') or ($_ eq '-keys') or ($_ eq '--keys')) {
			print'P             On Slotmachines: Enters a token or tokens and spins the reels'; print"\n";
			print'              On Table Games: Rolls the dice or spins the roulette wheel'; print"\n";
			print'              On Status Printout Machine: Prints game stats to a html file'; print"\n";
			print'            Meaning: Play'; print"\n";
			print'1P            On Slotmachines: Enters a token or tokens and spins the reels'; print"\n";
			print'            Meaning: Play One'; print"\n";
			print'2P,3P...8P    On Slotmachines: Enters tokens, selects multiple play lines,'; print"\n"; 
			print'                               and then spins the reels'; print"\n";
			print'            Meaning: Play Two, Play Three...Play Eight'; print"\n";
			print"\n";
			print'A             On Slotmachines: Executes the last entered valid command'; print"\n";
			print'              On Table Games: Rolls the dice or spins the roulette wheel'; print"\n";
			print'            Meaning: Again'; print"\n";
			print'B             On Table Games: Set your bet'; print"\n";
			print'            Meaning: Bet'; print"\n";
			print'C             On Slotmachines: Returns to casino menu'; print"\n";
			print'              On Table Games: Returns to casino menu'; print"\n";
			print'              On Status Printout Machine: Returns to casino menu'; print"\n";
			print'            Meaning: Casino Menu'; print"\n";
			print'EXIT          On Slotmachines: Quits game'; print"\n";
			print'              On Table Games: Quits game'; print"\n";
			print'              On Status Printout Machine: Quits game'; print"\n";
			print'              On Casino Menu: Quits game'; print"\n";
			print'            Meaning: Exit game'; print"\n";
			print'N             On Table Games: Select numbers to bet on'; print"\n";
			print'            Meaning: Numbers'; print"\n";
			print"\n";
			print'1,2,3...10    On Casino Menu: Selects and enters a subgame'; print"\n";
			print'            Meaning: Select Game One, Two, Three... Ten'; print"\n";
			exit();
			}
			
		}
		$name = '                            WELCOME TO MIKEEUSA\'S                               ';
		$namedeath = '                          YOU HAVE DIED IN MIKEEUSA\'S                           ';
		$nametog = 0;
		$buff0 = '';
		foreach(@ARGV) {
			if ($nametog == 1) {
				$name = $_;
				$name =~ s/[^a-zA-Z0-9_ \:\?\.\,\"\;\`\~\\\/\[\]\{\}\!\@\#\$\%\^\&\*\-\_\=\+\(\)]//g;
				$namechars = 0;
				
				while ($name =~ /[a-zA-Z0-9_ \:\?\.\,\"\;\`\~\\\/\[\]\{\}\!\@\#\$\%\^\&\*\-\_\=\+\(\)]/g) {
					$namechars = $namechars + 1;
				}
				
				#Odd or even?
				$buff0 = ($namechars/2);
				($buff1, $buff0) = split(/./,$buff0, 2);

				if ($buff0 == .5) {
				#Odd Number
				#Offsets ("38" "42") are not equal because the welcome and death screen text is not perfectly centered.
					$buff0 = ' 'x(38 - (($namechars+1)/2));
					$name = "$buff0"."$name";
					$buff0 = ' 'x(42 - (($namechars-1)/2));
					$name = "$name"."$buff0";
				} else {
				#Even Number
				#Offsets ("38" "42") are not equal because the welcome and death screen text is not perfectly centered.
					$buff0 = ' 'x(38 - ($namechars/2));
					$buff1 = ' 'x(42 - ($namechars/2));
					$name = "$buff0"."$name"."$buff1";
					
				}
				
				$namedeath = $name;
				
				$buff0 = '';
				$buff1 = '';
				$nametog = 0;
			} elsif (($_ eq '--name') or ($_ eq '-name')) {
				$nametog = 1;
			}
		}
	}
}

BEGIN {
	print"\n";
	print'GPCSLOTS 2'; print"\n";
	print' By The Entity Known As MikeeUSA'; print"\n";
	print"\n";
	print'This program is free software; you can redistribute it and/or'; print"\n";
	print'modify it under the terms of the GNU General Public License'; print"\n";
	print'as published by the Free Software Foundation; either version 2'; print"\n";
	print'of the License, or (at your option) any later version.'; print"\n";
	print"\n";
	print'This program is distributed in the hope that it will be useful,'; print"\n";
	print'but WITHOUT ANY WARRANTY; without even the implied warranty of'; print"\n";
	print'MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the'; print"\n";
	print'GNU General Public License for more details.'; print"\n";
	print"\n";
	print'You should have received a copy of the GNU General Public License'; print"\n";
	print'along with this program; if not, write to the Free Software'; print"\n";
	print'Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.'; print"\n";
	print"\n";
	print'WWW: https://cat2.dynu.ca    '; print"\n";
	print'IRC: cat2.dynu.ca  #linux    '; print"\n";
	print"\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n";
	print'	                                                                              '; print"\n";
	print'                                                                                '; print"\n";
	print'                                                                                '; print"\n";
	print"$name"; print"\n";
	print'                               GENERAL PUBLIC                                   '; print"\n";
	print'                                                                                '; print"\n";
	print'                           SSSSSS     IIIIIIIIIII                               '; print"\n";
	print'                         SSSSSSSSSS  IIIIIIIIIIIII                              '; print"\n";
	print'                        SSSS    SSSS     IIIII                                  '; print"\n";
	print'                  A     SSS              IIIII      NNNN     NNNNN              '; print"\n";
	print'                 AAA    SSSS             IIIII      NNNNN     NNN               '; print"\n";
	print'                AAAAA    SSSSSSSSS       IIIII      NNNNNN    NNN               '; print"\n";
	print'               AAAAAAA    SSSSSSSSS      IIIII      NNNNNNN   NNN               '; print"\n";
	print'    CCCCCC    AAAA AAAA         SSSS     IIIII      NNN NNNN  NNN     OOOOOOO   '; print"\n";
	print'  CCCCCCCCCC  AAA   AAA          SSS     IIIII      NNN  NNNN NNN   OOOOOOOOOOO '; print"\n";
	print' CCCC    CCCC AAAAAAAAA SSSS    SSSS     IIIII      NNN   NNNNNNN  OOOOO   OOOOO'; print"\n";
	print' CCC          AAA   AAA  SSSSSSSSSS  IIIIIIIIIIIII  NNN    NNNNNN  OOOO     OOOO'; print"\n";
	print' CCC          AAA   AAA    SSSSSS     IIIIIIIIIII   NNN     NNNNN  OOOO     OOOO'; print"\n";
	print' CCCC    CCCC AAA   AAA                            NNNNN     NNNN  OOOOO   OOOOO'; print"\n";
	print'  CCCCCCCCCC                                                        OOOOOOOOOOO '; print"\n";
	print'    CCCCCC                                                            OOOOOOO   '; print"\n";
	print'                                                                                '; print"\n";
	print'                                                                                '; print"\n";
	print'                                                                                '; print"\n";
	print'                                 [LOADING]                                      '; print"\n";
	print'                                                                                '; print"\n";
	print'                                                                                '; print"\n";
	print'                                                                                '; print"\n";
	print'                                                                                '; print"\n";
	print'                                                                                '; print"\n";
}

startup();

sub startup {
	colorset_normal();
	testmusic();
	beginmusic();
	setslotrandnums();
	$version = '0.4.5'; #0.4.5 in progress.
	$loadsavefile = 0;
	$buff0 = '';	#Used Often
	$buff1 = '';
	$buff2 = '';	#Only used when Buff0 and 1 are concurrently in use
	$buff3 = '';
	$buff4 = '';
	$hrbonus = 0;
	$hrbonushlp = 0;
	$hrbonusstd = 100; #How many bonus rounds are given out on triple bonus symbol win.
	$hrbonushlpstd = 4;#Determines if there are increased odds of bonus after triple bells, Set to 1 more then the number of turns you want.
	$hrbulbcolor = 'null'; #Blackened Bulbs
	$ccrapswin = 0;
	$ccrapslose = 0;
	$ccrapstie = 0; 
	$ccrapspoint = 0; 
	$ccrapscraps = 0;
	$ccrapsnumberofrolls = 0;
	$ccrapsstart2 = ' ';
	$ccrapsadded = 0;
	$ccrapsstart2 = ' ';
	$sbtstart2 = ' ';
	$proadd = 0;
	$startmoney = 100;
	$coin = 1; #What Each Slot Machine Token is Worth in coin.
	$coineval = 0;	#Do we evaluate what a token should be worth every play?
	$coinmultiple = 0; #If so, what has the user set this multiple to be (should be a less than 1 multiple)
	$money = $startmoney;
	$runmain = 1;
	$moneyexp = 0;
	$lvrmoney = 0;
	$lvrbet = 0;
	$lvrsetup = 0; # 0 = Monte Carlo Roulette, 1 = Roulette De Americana
	$lvrfuturecarlo = 0; # 0 = Classic Monte Carlo Roulette, 1 = Futuristic Spinner
	$lvrimprison = 0;
	$rllvrbet = 0;
	$rllvrsetup = 0; # 0 = Monte Carlo Roulette, 1 = Roulette De Americana
	$rllvrfuturecarlo = 0; # 0 = Classic Monte Carlo Roulette, 1 = Futuristic Spinner
	$sbtnumber = 0;
	$sbtbet = 0;
	$sbtmoney = 0;
	$ccrapsnumber = 0;
	$ccrapsbet = 0;
	$ccrapsmoney = 0;
	$ccrapssetup = 0;
	$spins = 0;
	$projkpot = 20000000;
	$projkpot2 = 1592837;
	$addmoney = 0;
	$ddaddmoney = 0;
	$ngemangemmoney = 0;
	$ruskiemoney = 0;
	$x = 'null';
	$ddx = ' ';
	$ddstartreel = 1;
	$potluckplaylevel = 0;
	$potluckapotluckmoney = 0;
	$potluckxP1p = ' ';
	$potluckxP1Zp = ' ';
	$potluckxP2p = ' ';
	$potluckxP2Zp = ' ';
	$potluckxP2p4x1 = ' ';
	$potluckxP2p4x2 = ' ';
	$potluckxP3p = ' ';
	$potluckxP3Zp = ' ';
	$potluckxP3p4x1 = ' ';
	$potluckxP3p4x2 = ' ';
	$potluckxP4p = ' ';
	$potluckxP4Zp = ' ';
	$potluckxP5p = ' ';
	$potluckxP5Zp = ' ';
	$potluckxP6p = ' ';
	$potluckxP6Zp = ' ';
	$potluckxP7p = ' ';
	$potluckxP7Zp = ' ';
	$potluckxP8p = ' ';
	$potluckxP8Zp = ' ';
	$potluckstartreel = 1;
	$ngemsymbol = 0;
	$ngemplaylevel = 0;
	$ngemx12 = ' ';
	$ngemx23 = ' ';
	$ngemx34 = ' ';
	$ngemx45 = ' ';
	$ngemx123 = ' ';
	$ngemx234 = ' ';
	$ngemx345 = ' ';
	$ngemx1234 = ' ';
	$ngemx2345 = ' ';
	$ngemx12345 = ' ';
	$ngemstartreel = 1;
	$anybar = 0;
	$anybar1 = 0;
	$anybar2 = 0;
	$anybar3 = 0;
	$anycherry = 0;
	$anycherry1 = 0;
	$anycherry2 = 0;
	$anycherry3 = 0;
	$onecherry = 0;
	$nonep = 0;
	$startreel = 1;
	$anydollar = 0;
	$anydollar1 = 0;
	$anydollar2 = 0;
	$anydollar3 = 0;
	$reelspin = 0;
	$ddreelspin = 0;
	$ssreelspin = 0;
	$ngemreelspin = 0;
	$potluckreelspin = 0;
	$lvrreelspin = 0;
	$rllvrreelspin = 0;
	$ssaddmoney = 0;
	$ssaddmoney1 = 0;
	$ssaddmoney2 = 0;
	$ssaddmoney3 = 0;
	$ssaddmoney4 = 0;
	$ssaddmoney5 = 0;
	$ssx1 = 'null';
	$ssx2 = 'null';
	$ssx3 = 'null';
	$ssx4 = 'null';
	$ssx5 = 'null';
	$sslines = 1;
	$ssmisalign1 = 0;
	$ssmisalign2 = 0;
	$ssmisalign3 = 0;
	$lvrstart1 = ' ';
	$lvrstart2 = ' ';
	$lvrwinnbr = 0;
	$rllvrstart1 = ' ';
	$rllvrstart2 = ' ';
	$rllvrwinnbr = 0;
	$hrstspins = 0;
	$ddstspins = 0;
	$ssstspins = 0;
	$ruskiestspin = 0;
	$lvrstspins = 0;
	$rllvrstspins = 0;
	$sbtstspins = 0;
	$ccrapsstspins = 0;
	$ngemstspins = 0;
	$potluckstspins = 0;
	$hrstwin = 0;
	$hrstlose = 0;
	$ngemstwin = 0;
	$ngemstlose = 0;
	$potluckstwin = 0;
	$potluckstlose = 0;
	$ruskieold = 0;
	$ddstwin = 0;
	$ddstlose = 0;
	$ssstwin = 0;
	$ssstlose = 0;
	$rrstwin = 0;
	$rrstlose = 0;
	$lvrstwin = 0;
	$lvrstlose = 0;
	$rllvrstwin = 0;
	$rllvrstlose = 0;
	$sbtstwin = 0;
	$sbtstlose = 0;
	$ccrapsstwin = 0;
	$ccrapsstlose = 0;
	$esegpenguinhrs = 0;
	$hrstmc = 0;
	$ddstmc = 0;
	$ssstmc = 0;
	$ngemstmc = 0;
	$potluckstmc = 0;
	$rrstmc = 0;
	$lvrstmc = 0;
	$rllvrstmc = 0;
	$sbtstmc = 0;
	$ccrapsstmc = 0;
	$hrstmc2 = 0;
	$ddstmc2 = 0;
	$ssstmc2 = 0;
	$rrstmc2 = 0;
	$lvrstmc2 = 0;
	$rllvrstmc2 = 0;
	$sbtstmc2 = 0;
	$ccrapsstmc2 = 0;
	$ngemstmc2 = 0;
	$potluckstmc2 = 0;
	$beepnum = 0;
	$banktruesavrte = 0.03; #Bank savings account interest rate.
	$banksavperiod = 1000;	#Period, (Example X% per Annum)
	$banksavcpndintvl = 10000000; #How many turns before interest is compounded
	$banksavingintvl = 0; #Counter
	$banksavintrst = 0; #This period's interest
	$banksavmoney = 0; #The acctual account
	$banksavsprncpletrk = 0; #Tracks all deposits over the life of the account
	$banksavswthdrwtrk = 0; #Tracks all withdrawals over the life of the account
	$banksavsprncple = 0; #Current Deposited Principle
	$banksavecrintsttrk = 0; #Tracks Current Intrest (total - principle)
	$banksavintrsttrk = 0; #Tracks the total earned interest over the life of the account
	$bankdepst = 0;
	$bankwtdrl = 0;
	$bankstkbuy = 0;
	$bankstksell = 0;
	$bankstkpttotal = 0;
	$bankfndmorinfo = 0;
	##$ssagaincmd;
	##$ddagaincmd;
	##$ngemagaincmd;
	##$hragaincmd;
	$savefile = '.gpcs2-savefile';
	$loadedsavefile = 0;
	$allowhtml = 1; #Set to 0 if you are going to use GPC-Slots 2 as a user's shell :)
	$allowsave = 1; #Set to 0 if you do not want a user to beable to save his progress.
	$htmlcolor0 = 'BLACK';     #background color
	$htmlcolor1 = 'GREY';      #text color
	$htmlcolor2 = 'LIGHTBLUE'; #logo a
	$htmlcolor3 = 'BLUE';      #logo b
	$htmlcolor4 = 'YELLOW';    #logo c
	$htmlcolor5 = 'RED';    #link color
	$htmlcolor6 = 'DARKGREY';    #link color
	$htmlcolor7 = 'GREY';      #text color
	$htmltitle = 'GPCSlots2-Stats';
	@ptracker = ("$money");
	if ($startmoney >= 500) {
		$htmldivide = ($startmoney/20);
	} else {
		$htmldivide = ($startmoney/10);
	}
	$htmldivide = sprintf("%.0f", $htmldivide );
	
	commandargs();
	computesverte();
	if (($loadsavefile == 1) && ($allowsave == 1)) {
		loadsavefile();
		zerosavefile();
		$loadsavefile = 0;
		$loadedsavefile = 1;
	}
	stockmarketinit();
	spinreel();
	ddspinreel();
	ssspinreel();
	ngem45init();
	ngemspinreel();
	potluck45init();
	potluckspinreel();
	ruskieinit();
	lvrnbrreset();
	lvrspin();
	rllvrnbrreset();
	rllvrspin();
	sbtresetnum();
	sbtthrowdice();
	ccrapsresetnum();
	ccrapsthrowdice();
	titlemain();
}

sub setslotrandnums {
	#House Rules Reel Deel
	$hrrandnums = 107;     #No Bonus 103 #Bonus 107
	#Potluck
	$potluckrandnums = 53; #Old Standard 50  #Profitable to casino at 53 and above
}

sub colorset_normal {
	$bgcwhite = 'white';
	$bgcblack = 'black';
	$bgcred = 'red';
	$bgcgreen = 'green';
	$bgcblue = 'blue';
	$bgccyan = 'cyan';
	$bgcyellow = 'yellow';
	$bgcmagenta = 'magenta';
	$white = 'white';
	$black = 'black';
	$red = 'red';
	$green = 'green';
	$blue = 'blue';
	$cyan = 'cyan';
	$yellow = 'yellow';
	$magenta = 'magenta';
	$boldwhite = 'bold white';
	$boldblack = 'bold black';
	$boldred = 'bold red';
	$boldgreen = 'bold green';
	$boldblue = 'bold blue';
	$boldcyan = 'bold cyan';
	$boldyellow = 'bold yellow';
	$boldmagenta = 'bold magenta';	

	$titlecolor = "$blue";
	$decsscolor = "$green";
	$sspx2 = "$boldgreen";
	$sspx3 = "$boldgreen";
}

sub colorset_dull {
	$bgcwhite = 'white';
	$bgcblack = 'black';
	$bgcred = 'red';
	$bgcgreen = 'green';
	$bgcblue = 'blue';
	$bgccyan = 'cyan';
	$bgcyellow = 'yellow';
	$bgcmagenta = 'magenta';
	$white = 'white';
	$black = 'black';
	$red = 'red';
	$green = 'green';
	$blue = 'blue';
	$cyan = 'cyan';
	$yellow = 'yellow';
	$magenta = 'magenta';
	$boldwhite = 'white';
	$boldblack = 'black';
	$boldred = 'red';
	$boldgreen = 'green';
	$boldblue = 'blue';
	$boldcyan = 'cyan';
	$boldyellow = 'yellow';
	$boldmagenta = 'magenta';	

	$titlecolor = "$blue";
	$decsscolor = "$green";
	$sspx2 = "$boldgreen";
	$sspx3 = "$boldgreen";
}

sub colorset_bright {
	$bgcwhite = 'white';
	$bgcblack = 'black';
	$bgcred = 'red';
	$bgcgreen = 'green';
	$bgcblue = 'blue';
	$bgccyan = 'cyan';
	$bgcyellow = 'yellow';
	$bgcmagenta = 'magenta';
	$white = 'bold white';
	$black = 'bold black';
	$red = 'bold red';
	$green = 'bold green';
	$blue = 'bold blue';
	$cyan = 'bold cyan';
	$yellow = 'bold yellow';
	$magenta = 'bold magenta';
	$boldwhite = 'bold white';
	$boldblack = 'bold black';
	$boldred = 'bold red';
	$boldgreen = 'bold green';
	$boldblue = 'bold blue';
	$boldcyan = 'bold cyan';
	$boldyellow = 'bold yellow';
	$boldmagenta = 'bold magenta';	

	$titlecolor = "$blue";
	$decsscolor = "$green";
	$sspx2 = "$boldgreen";
	$sspx3 = "$boldgreen";
}

sub colorset_inverse {
	$bgcwhite = 'black';
	$bgcblack = 'white';
	$bgcred = 'cyan';
	$bgcgreen = 'magenta';
	$bgcblue = 'yellow';
	$bgccyan = 'red';
	$bgcyellow = 'blue';
	$bgcmagenta = 'green';
	$white = 'black';
	$black = 'white';
	$red = 'cyan';
	$green = 'magenta';
	$blue = 'yellow';
	$cyan = 'red';
	$yellow = 'blue';
	$magenta = 'green';	
	$boldwhite = 'bold black';
	$boldblack = 'bold white';
	$boldred = 'bold cyan';
	$boldgreen = 'bold magenta';
	$boldblue = 'bold yellow';
	$boldcyan = 'bold red';
	$boldyellow = 'bold blue';
	$boldmagenta = 'bold green';	

	$titlecolor = "$blue";
	$decsscolor = "$green";
	$sspx2 = "$boldgreen";
	$sspx3 = "$boldgreen";
}

sub colorset_notld {
	$bgcwhite = 'red';
	$bgcblack = 'black';
	$bgcred = 'red';
	$bgcgreen = 'red';
	$bgcblue = 'red';
	$bgccyan = 'red';
	$bgcyellow = 'red';
	$bgcmagenta = 'red';
	$white = 'white';
	$black = 'black';
	$red = 'bold red';
	$green = 'green';
	$blue = 'blue';
	$cyan = 'cyan';
	$yellow = 'yellow';
	$magenta = 'magenta';
	$boldwhite = 'bold white';
	$boldblack = 'bold black';
	$boldred = 'bold red';
	$boldgreen = 'bold green';
	$boldblue = 'bold blue';
	$boldcyan = 'bold cyan';
	$boldyellow = 'bold yellow';
	$boldmagenta = 'bold magenta';	

	$titlecolor = "$blue";
	$decsscolor = "$green";
	$sspx2 = "$boldgreen";
	$sspx3 = "$boldgreen";
}

sub colorset_lightsout {
	$bgcwhite = 'black';
	$bgcblack = 'black';
	$bgcred = 'black';
	$bgcgreen = 'black';
	$bgcblue = 'black';
	$bgccyan = 'black';
	$bgcyellow = 'black';
	$bgcmagenta = 'black';
	$white = 'white';
	$black = 'black';
	$red = 'red';
	$green = 'green';
	$blue = 'blue';
	$cyan = 'cyan';
	$yellow = 'yellow';
	$magenta = 'magenta';	
	$boldwhite = 'bold white';
	$boldblack = 'bold black';
	$boldred = 'bold red';
	$boldgreen = 'bold green';
	$boldblue = 'bold blue';
	$boldcyan = 'bold cyan';
	$boldyellow = 'bold yellow';
	$boldmagenta = 'bold magenta';
			
	$titlecolor = "$blue";
	$decsscolor = "$green";
	$sspx2 = "$boldgreen";
	$sspx3 = "$boldgreen";
}

sub colorset_blackwhite {
	$bgcwhite = 'black';
	$bgcblack = 'black';
	$bgcred = 'black';
	$bgcgreen = 'black';
	$bgcblue = 'black';
	$bgccyan = 'black';
	$bgcyellow = 'black';
	$bgcmagenta = 'black';
	$white = 'white';
	$black = 'white';
	$red = 'white';
	$green = 'white';
	$blue = 'white';
	$cyan = 'white';
	$yellow = 'white';
	$magenta = 'white';	
	$boldwhite = 'bold white';
	$boldblack = 'bold white';
	$boldred = 'bold white';
	$boldgreen = 'bold white';
	$boldblue = 'bold white';
	$boldcyan = 'bold white';
	$boldyellow = 'bold white';
	$boldmagenta = 'bold white';		

	$titlecolor = "$blue";
	$decsscolor = "$green";
	$sspx2 = "$boldgreen";
	$sspx3 = "$boldgreen";
}

our $execution_of_commandargs;
sub commandargs {
	if(!$execution_of_commandargs)
	{
		$SEP = ''
	}

	foreach(@ARGV) {
		if (($_ eq '-nan') or ($_ eq '--no-ansi')) {
			if ($compatANSI != 0) {
				$ENV{ANSI_COLORS_DISABLED} = 1;
			}
			$compatANSI = 0;	
		}
		
		if (($_ eq '-an') or ($_ eq '--ansi')) {
			if ($compatANSI != 1) {
				delete $ENV{ANSI_COLORS_DISABLED};
			}
			$compatANSI = 1;
		}
		
		if (($_ eq '-na') or ($_ eq '--no-animation')) {
			$animate = 0;	
		}
		
		if (($_ eq '-a') or ($_ eq '--animation')) {
			$animate = 1;	
		}
		
		if (($_ eq '-nt') or ($_ eq '--no-vt100')) {
			$compatVT100 = 0;	
		}
		
		if (($_ eq '-t') or ($_ eq '--vt100')) {
			$compatVT100 = 1;	
		}
		
		if (($_ eq '-nu') or ($_ eq '--no-unix')) {
			$compatUNIXY = 0;	
		}
		
		if (($_ eq '-u') or ($_ eq '--unix')) {
			$compatUNIXY = 1;	
		}
		
		if (($_ eq '-nsfx') or ($_ eq '--no-soundfx')) {
			$soundfx = 0;	
		}
		
		if (($_ eq '-2') or ($_ eq '--dual')) {
			$SEP = "\377" if !$execution_of_commandargs;
		}
		
		if (($_ eq '-sfx') or ($_ eq '--soundfx')) {
			$soundfx = 1;	
		}
		
		if (($_ eq '-npt') or ($_ eq '--no-playtracking')) {
			$playtrack = 0;	
		}
		
		if (($_ eq '-pt') or ($_ eq '--playtracking')) {
			$playtrack = 1;	
		}
		
		if (($_ eq '-nm') or ($_ eq '--no-music')) {
			if ($music == 1) {
				killmusic();
				$music = 0;
			} else {
				$music = 0;
			}	
		}
		
		if (($_ eq '-m') or ($_ eq '--music')) {
			if ($music == 0) {
				$music = 1;
				testmusic();
				beginmusic();
			} else {
				$music = 1;
			}	
		}				
		
		if (($_ eq '-as1') or ($_ eq '--animation-speed-1')) {
			$anispeed = 1;	
		}
		
		if (($_ eq '-as2') or ($_ eq '--animation-speed-2')) {
			$anispeed = 2;	
		}
		
		if (($_ eq '-as3') or ($_ eq '--animation-speed-3')) {
			$anispeed = 3;	
		}
		
		if (($_ eq '-l') or ($_ eq '--load-savefile')) {
			$loadsavefile = 1;	
		}
	}

	if(!$execution_of_commandargs and $SEP ne '')
	{
		binmode STDOUT, ':via(PrintWrapper)';
	}
	$execution_of_commandargs = 1;
}

sub titlemain {
	while ($runmain == 1) {
		newlines();
		titlescreen();	
	}
}

sub titlescreen {
print colored('                                                                                ',"$boldyellow on_$bgcblack"); print"\n"; 
print colored('                                                                                ',"$boldyellow on_$bgcblack"); print"\n"; 
print colored("$name","$boldyellow on_$bgcblack"); print"\n"; 
print colored("                               GENERAL PUBLIC                                   ","$boldyellow on_$bgcblack"); print"\n"; 
print colored("                                                                                ","$boldyellow on_$bgcblack"); print"\n"; 
print colored('                           SSSSSS     IIIIIIIIIII                               ',"$titlecolor on_$bgcblack"); print"\n"; 
print colored('                         SSSSSSSSSS  IIIIIIIIIIIII                              ',"bold $titlecolor on_$bgcblack"); print"\n"; 
print colored('                        SSSS    SSSS     IIIII                                  ',"$titlecolor on_$bgcblack"); print"\n"; 
print colored('                  A     SSS              IIIII      NNNN     NNNNN              ',"bold $titlecolor on_$bgcblack"); print"\n"; 
print colored('                 AAA    SSSS             IIIII      NNNNN     NNN               ',"$titlecolor on_$bgcblack"); print"\n"; 
print colored('                AAAAA    SSSSSSSSS       IIIII      NNNNNN    NNN               ',"bold $titlecolor on_$bgcblack"); print"\n"; 
print colored('               AAAAAAA    SSSSSSSSS      IIIII      NNNNNNN   NNN               ',"$titlecolor on_$bgcblack"); print"\n";        
print colored('    CCCCCC    AAAA AAAA         SSSS     IIIII      NNN NNNN  NNN     OOOOOOO   ',"bold $titlecolor on_$bgcblack"); print"\n"; 
print colored('  CCCCCCCCCC  AAA   AAA          SSS     IIIII      NNN  NNNN NNN   OOOOOOOOOOO ',"$titlecolor on_$bgcblack"); print"\n"; 
print colored(' CCCC    CCCC AAAAAAAAA SSSS    SSSS     IIIII      NNN   NNNNNNN  OOOOO   OOOOO',"bold $titlecolor on_$bgcblack"); print"\n"; 
print colored(' CCC          AAA   AAA  SSSSSSSSSS  IIIIIIIIIIIII  NNN    NNNNNN  OOOO     OOOO',"$titlecolor on_$bgcblack"); print"\n"; 
print colored(' CCC          AAA   AAA    SSSSSS     IIIIIIIIIII   NNN     NNNNN  OOOO     OOOO',"bold $titlecolor on_$bgcblack"); print"\n"; 
print colored(' CCCC    CCCC AAA   AAA                            NNNNN     NNNN  OOOOO   OOOOO',"$titlecolor on_$bgcblack"); print"\n"; 
print colored('  CCCCCCCCCC                                                        OOOOOOOOOOO ',"bold $titlecolor on_$bgcblack"); print"\n"; 
print colored('    CCCCCC                                                            OOOOOOO   ',"$titlecolor on_$bgcblack"); print"\n"; 
print colored('                                                                                ',"$boldyellow on_$bgcblack"); print"\n"; 

if ($moneyexp > 9999999999999999999) {
print colored(" Expended Cash: ".sprintf("%.18e", $moneyexp)."  ","$white on_$bgcblack"); 
} elsif ($moneyexp >= 100000000000000000) {
print colored(" Expended Cash: $moneyexp        ","$white on_$bgcblack"); 
} elsif ($moneyexp >= 10000000000000000) {
print colored(" Expended Cash: $moneyexp         ","$white on_$bgcblack"); 
} elsif ($moneyexp >= 1000000000000000) {
print colored(" Expended Cash: $moneyexp          ","$white on_$bgcblack"); 
} elsif ($moneyexp >= 100000000000000) {
print colored(" Expended Cash: $moneyexp           ","$white on_$bgcblack"); 
} elsif ($moneyexp >= 10000000000000) {
print colored(" Expended Cash: $moneyexp            ","$white on_$bgcblack"); 
} elsif ($moneyexp >= 1000000000000) {
print colored(" Expended Cash: $moneyexp             ","$white on_$bgcblack"); 
} elsif ($moneyexp >= 100000000000) {
print colored(" Expended Cash: $moneyexp              ","$white on_$bgcblack"); 
} elsif ($moneyexp >= 10000000000) {
print colored(" Expended Cash: $moneyexp               ","$white on_$bgcblack"); 
} elsif  ($moneyexp >= 1000000000) {    
print colored(" Expended Cash: $moneyexp                ","$white on_$bgcblack"); 
} elsif  ($moneyexp >= 100000000) {
print colored(" Expended Cash: $moneyexp                 ","$white on_$bgcblack"); 
} elsif  ($moneyexp >= 10000000) {
print colored(" Expended Cash: $moneyexp                  ","$white on_$bgcblack");
} elsif  ($moneyexp >= 1000000) {
print colored(" Expended Cash: $moneyexp                   ","$white on_$bgcblack");
} elsif  ($moneyexp >= 100000) {
print colored(" Expended Cash: $moneyexp                    ","$white on_$bgcblack"); 
} elsif  ($moneyexp >= 10000) {
print colored(" Expended Cash: $moneyexp                     ","$white on_$bgcblack"); 
} elsif  ($moneyexp >= 1000) {
print colored(" Expended Cash: $moneyexp                      ","$white on_$bgcblack"); 
} elsif  ($moneyexp >= 100) {
print colored(" Expended Cash: $moneyexp                       ","$white on_$bgcblack"); 
} elsif  ($moneyexp >= 10) {
print colored(" Expended Cash: $moneyexp                        ","$white on_$bgcblack"); 
} elsif  ($moneyexp >= 0) {
print colored(" Expended Cash: $moneyexp                         ","$white on_$bgcblack"); 
} else {
print colored(" Expended Cash: $moneyexp                          ","$white on_$bgcred"); 
}

print colored("                      version $version   ","$boldblack on_$bgcblack"); print"\n"; 

tokeneval();
if ($coin > 9999999999999999999) {
print colored(" Slotmachine Token Value: ".sprintf("%.18e", $coin)."                              ","$white on_$bgcblack"); print"\n"; 
} elsif ($coin >= 1000000000000000000) {
print colored(" Slotmachine Token Value: $coin                                   ","$white on_$bgcblack"); print"\n"; 
} elsif ($coin >= 100000000000000000) {
print colored(" Slotmachine Token Value: $coin                                    ","$white on_$bgcblack"); print"\n"; 
} elsif ($coin >= 10000000000000000) {
print colored(" Slotmachine Token Value: $coin                                     ","$white on_$bgcblack"); print"\n"; 
} elsif ($coin >= 1000000000000000) {
print colored(" Slotmachine Token Value: $coin                                      ","$white on_$bgcblack"); print"\n"; 
} elsif ($coin >= 100000000000000) {
print colored(" Slotmachine Token Value: $coin                                       ","$white on_$bgcblack"); print"\n"; 
} elsif ($coin >= 10000000000000) {
print colored(" Slotmachine Token Value: $coin                                        ","$white on_$bgcblack"); print"\n"; 
} elsif ($coin >= 1000000000000) {
print colored(" Slotmachine Token Value: $coin                                         ","$white on_$bgcblack"); print"\n"; 
} elsif ($coin >= 100000000000) {
print colored(" Slotmachine Token Value: $coin                                          ","$white on_$bgcblack"); print"\n"; 
} elsif ($coin >= 10000000000) {
print colored(" Slotmachine Token Value: $coin                                           ","$white on_$bgcblack"); print"\n"; 
} elsif  ($coin >= 1000000000) {
print colored(" Slotmachine Token Value: $coin                                            ","$white on_$bgcblack"); print"\n"; 
} elsif  ($coin >= 100000000) {
print colored(" Slotmachine Token Value: $coin                                             ","$white on_$bgcblack"); print"\n"; 
} elsif  ($coin >= 10000000) {
print colored(" Slotmachine Token Value: $coin                                              ","$white on_$bgcblack"); print"\n"; 
} elsif  ($coin >= 1000000) {
print colored(" Slotmachine Token Value: $coin                                               ","$white on_$bgcblack"); print"\n"; 
} elsif  ($coin >= 100000) {
print colored(" Slotmachine Token Value: $coin                                                ","$white on_$bgcblack"); print"\n"; 
} elsif  ($coin >= 10000) {
print colored(" Slotmachine Token Value: $coin                                                 ","$white on_$bgcblack"); print"\n"; 
} elsif  ($coin >= 1000) {
print colored(" Slotmachine Token Value: $coin                                                  ","$white on_$bgcblack"); print"\n"; 
} elsif  ($coin >= 100) {
print colored(" Slotmachine Token Value: $coin                                                   ","$white on_$bgcblack"); print"\n"; 
} elsif  ($coin >= 10) {
print colored(" Slotmachine Token Value: $coin                                                    ","$white on_$bgcblack"); print"\n"; 
} elsif  ($coin >= 0) {
print colored(" Slotmachine Token Value: $coin                                                     ","$white on_$bgcblack"); print"\n"; 
} else {
print colored(" Slotmachine Token Value: $coin                                                      ","$white on_$bgcred"); print"\n"; 
}

print colored('                                                                                ',"$boldwhite on_$bgcblack"); print"\n"; 
print colored('CHOOSE WHICH SLOT MACHINE YOU WISH TO PLAY                                      ',"$boldwhite on_$bgcblack"); print"\n";
print colored('1) House Rules Reel Deal     5) PotLuck                9) Sic Bo Tai Sai        ',"$boldwhite on_$bgcblack"); print"\n"; 
print colored('2) Double Blue Diamond       6) Russian Roulette      10) Casino Craps          ',"$boldwhite on_$bgcblack"); print"\n";

if ($esegpenguinhrs != 1) {
	print colored('3) High Roller Sevens        ',"$boldwhite on_$bgcblack");
} else { 
	print colored('3) High Roller Penguins      ',"$boldwhite on_$bgcblack"); 
}
if ($lvrsetup == 0) { 
	print colored('7) Monte Carlo Roulette ',"$boldwhite on_$bgcblack"); 
} else { 
	print colored('7) Roulette De Americana',"$boldwhite on_$bgcblack"); 
}
print colored(' 11) Bank                  ',"$boldwhite on_$bgcblack");
print"\n"; 

print colored('4) Twilight Mine             8) Real Vegas Roulette   ',"$boldwhite on_$bgcblack");
if ($allowhtml == 1) {
	print colored('12) Status Printout       ',"$boldwhite on_$bgcblack");              
} else {
	print colored('12) N/A                   ',"$boldwhite on_$bgcblack");              
}
print"\n"; 
print color 'white';
	$titlescreen = <STDIN>;
	chomp($titlescreen);
print color 'reset';
	if ($titlescreen == 1) {
		newlines();
		main2();
	} elsif ($titlescreen == 2) { 
		newlines();
		ddmain2();
	} elsif ($titlescreen == 3) { 
		newlines();
		ssmain2();
	} elsif ($titlescreen == 11) {
		newlines();
		if ($music == 1) {
			killmusic();
			$music = 1;
			bankbeginmusic();
		} else {
			#NOTHING!
		}
		newlines();
		bankmachine();
	} elsif ($titlescreen == 12) { 
		if ($allowhtml == 1) {
			newlines();
			statsmachine();
		} else {
			#Nothing
		}
	} elsif ($titlescreen == 4) {
		newlines();
		ngemmain2();
	} elsif ($titlescreen == 5) {
		newlines();
		potluckmain2();			
	} elsif ($titlescreen == 6) {
		newlines();
		if (($music == 1) and ($ruskieold == 0)) {
			killmusic();
			$music = 1;
			rrbeginmusic();
		} else {
			#NOTHING!
		}
		newlines();
		ruskieroll2();
	} elsif ($titlescreen == 7) {
		newlines();
		lvrmainspin2();
	} elsif ($titlescreen == 8) {
		newlines();
		rllvrmainspin2();
	} elsif ($titlescreen == 9) {
		newlines();
		sbtmainspin2();
	} elsif ($titlescreen == 10) {
		newlines();
		ccrapsmainspin2();					 			
	} elsif (($titlescreen eq 'exit') or ($titlescreen eq 'EXIT') or ($titlescreen eq 'quit') or ($titlescreen eq 'QUIT')) {
		exitgame();
	} elsif (($titlescreen eq 'decss') or ($titlescreen eq 'DECSS'))  {
		newlines();
		viewdecss();
	} elsif (($titlescreen eq 'feminism') or ($titlescreen eq 'women')
		or ($titlescreen eq 'women\'s rights') or ($titlescreen eq '19th ammendment')
		or ($titlescreen eq 'women\'s vote')
		or ($titlescreen eq 'FEMINISM') or ($titlescreen eq 'WOMEN')
		or ($titlescreen eq 'WOMEN\'S RIGHTS') or ($titlescreen eq '19TH AMMENDMENT')
		or ($titlescreen eq 'WOMEN\'S VOTE'))  {
		newlines();	
		nosexism();
	} elsif (($titlescreen eq '-h') or ($titlescreen eq '--help') or ($titlescreen eq 'help') or ($titlescreen eq 'HELP') or ($titlescreen eq 'h') or ($titlescreen eq 'H')) {
		newlines();
		help();
		<STDIN>;
	} elsif (($titlescreen eq '-k') or ($titlescreen eq '--keys') or ($titlescreen eq 'keys') or ($titlescreen eq 'KEYS') or ($titlescreen eq 'commands') or ($titlescreen eq 'COMMANDS') or ($titlescreen eq 'k') or ($titlescreen eq 'K')) {
		newlines();
		helpkeys();
		<STDIN>;	
	} elsif (($titlescreen eq 'highrollerpenguins') or ($titlescreen eq 'HIGHROLLERPENGUINS')) {				
		if ($esegpenguinhrs == 0) {
			$esegpenguinhrs = 1;
		} else {
			$esegpenguinhrs = 0;
		}
	} elsif (($titlescreen eq 'twilightdiamonds') or ($titlescreen eq 'TWILIGHTDIAMONDS')) {				
		if ($ngemsymbol == 0) {
			$ngemsymbol = 1;
		} else {
			$ngemsymbol = 0;
		}
	} elsif (($titlescreen eq 'overtheocean') or ($titlescreen eq 'OVERTHEOCEAN')) {				
		if ($lvrsetup == 0) {
			$lvrsetup = 1;
		} else {
			$lvrsetup = 0;
		}
	} elsif (($titlescreen eq 'futurecarlo') or ($titlescreen eq 'FUTURECARLO')) {
		$lvrfuturecarlo = 1;
	} elsif (($titlescreen eq 'oldworldcharm') or ($titlescreen eq 'OLDWORLDCHARM')) {
		$lvrfuturecarlo = 0;
	} elsif (($titlescreen eq 'futurevegas') or ($titlescreen eq 'FUTUREVEGAS')) {
		$rllvrfuturecarlo = 1;
	} elsif (($titlescreen eq 'oldvegas') or ($titlescreen eq 'OLDVEGAS')) {
		$rllvrfuturecarlo = 0;
	} elsif (($titlescreen eq 'bluecraps') or ($titlescreen eq 'BLUECRAPS')) {
		$ccrapssetup = 0;
	} elsif (($titlescreen eq 'greencraps') or ($titlescreen eq 'GREENCRAPS')) {
		$ccrapssetup = 1;
	} elsif (($titlescreen eq 'cyancraps') or ($titlescreen eq 'CYANCRAPS')) {
		$ccrapssetup = 2;
	} elsif (($titlescreen eq 'highrollersevens') or ($titlescreen eq 'HIGHROLLERSEVENS')) {
		$esegpenguinhrs = 0;
	} elsif (($titlescreen eq 'twilightemeralds') or ($titlescreen eq 'TWILIGHTEMERALDS')) {
		$ngemsymbol = 0;
	} elsif (($titlescreen eq 'oldguard') or ($titlescreen eq 'OLDGUARD')) {
		$ruskieold = 1;
	} elsif (($titlescreen eq 'newguard') or ($titlescreen eq 'NEWGUARD')) {
		$ruskieold = 0;		
	} elsif (($titlescreen eq 'lightsout') or ($titlescreen eq 'LIGHTSOUT')) {				
		colorset_lightsout();
	} elsif (($titlescreen eq 'lightson') or ($titlescreen eq 'LIGHTSON')) {				
		colorset_normal();
	} elsif (($titlescreen eq 'wedidnthavecolor') or ($titlescreen eq 'WEDIDNTHAVECOLOR')) {				
		colorset_blackwhite();
	} elsif (($titlescreen eq 'gammarayburst') or ($titlescreen eq 'GAMMARAYBURST')) {				
		colorset_inverse();
	} elsif (($titlescreen eq 'dulltimes') or ($titlescreen eq 'DULLTIMES')) {				
		colorset_dull();
	} elsif (($titlescreen eq 'brighttimes') or ($titlescreen eq 'BRIGHTTIMES')) {				
		colorset_bright();
	} elsif (($titlescreen eq 'nightofthelivingdead') or ($titlescreen eq 'NIGHTOFTHELIVINGDEAD')) {				
		colorset_notld();
	} else {
		@ARGV = $titlescreen;
		commandargs();
	}
	
	return;
}

sub viewdecss {
print colored('     BEHOLD ALL YEE WHOM ENTER! ILLEGAL PRIME NUMBER OF DECSS FROM EFDTT.C:     ',"$boldyellow on_$bgcblack"); print"\n"; 
print colored('                                                                                ',"$boldyellow on_$bgcblack"); print"\n"; 
print colored('                                                   9454 7005113906              ',"$decsscolor on_$bgcblack"); print"\n";
print colored('            4445500929 6776927869 3366458905 0222897871 4950867838              ',"$decsscolor on_$bgcblack"); print"\n";
print colored('            0500658547 1078776889 6313320081 6447475865 9031815003              ',"$decsscolor on_$bgcblack"); print"\n";
print colored('            9822306942 1701682469 8468953527 7506293328 0780994198              ',"$decsscolor on_$bgcblack"); print"\n";
print colored('            5641052653 3345462508 4314006874 6551409510 2042852544              ',"$decsscolor on_$bgcblack"); print"\n";
print colored('            1264820432 9860820006 7866922287 2721350789 7567520105              ',"$decsscolor on_$bgcblack"); print"\n";
print colored('            6069007944 6509850383 1481013904 8399479601 6226100635              ',"$decsscolor on_$bgcblack"); print"\n";
print colored('            3638384224 3246104161 3899207128 5187220887 2165636447              ',"$decsscolor on_$bgcblack"); print"\n";
print colored('            9923851594 8762313652 6386601309 8356062871 2571853106              ',"$decsscolor on_$bgcblack"); print"\n";
print colored('            5809023364 7322143645 8421842236 2536427009 5557239142              ',"$decsscolor on_$bgcblack"); print"\n";
print colored('            1165512411 2039883768 2243428924 2349301261 7418161246              ',"$decsscolor on_$bgcblack"); print"\n";
print colored('            3034415778 2839809597 6436852468 9078864161 4306545276              ',"$decsscolor on_$bgcblack"); print"\n";
print colored('            8956715245 9477708733 4644014469 5871931815 7608776778              ',"$decsscolor on_$bgcblack"); print"\n";
print colored('            2573341499 4188265086 0668841859 9672379789 3766678068              ',"$decsscolor on_$bgcblack"); print"\n";
print colored('            2566994676 0998769793 4508344702 2603175841 3304926144              ',"$decsscolor on_$bgcblack"); print"\n";
print colored('            6761328219 9729121409 9335596945 7407499011 1540914866              ',"$decsscolor on_$bgcblack"); print"\n";
print colored('            1355366182 1056035804 0014112275 1532956922 4393582188              ',"$decsscolor on_$bgcblack"); print"\n";
print colored('            9493881197 1105655941 1852982478 7238592254 0525772073              ',"$decsscolor on_$bgcblack"); print"\n";
print colored('            4123557637 2341117844 3887252022 3019576406 0843081469              ',"$decsscolor on_$bgcblack"); print"\n";
print colored('                                                                                ',"$boldyellow on_$bgcblack"); print"\n"; 
print colored('"Suppose you were to take a variant of efdtt.c, a program that will allow you to',"$boldyellow on_$bgcblack"); print"\n";
print colored('  play a DVD on a computer, and then convert each character in the code to its  ',"$boldyellow on_$bgcblack"); print"\n"; 
print colored(' 7-bit ascii equivalent (the code contains standard characters, so the eight or ',"$boldyellow on_$bgcblack"); print"\n";
print colored('leading bit is zero). Finally, view this string of bits as a single number. What',"$boldyellow on_$bgcblack"); print"\n"; 
print colored('                       do you get? This illegal prime!"                         ',"$boldyellow on_$bgcblack"); print"\n";
print colored('  This number was found to be a probable prime by Charles M. Hannum and proven  ',"$boldblack on_$bgcblack"); print"\n";
print colored('                              prime by Phil Carmody                             ',"$boldblack on_$bgcblack"); print"\n";
print color 'black';
	$placeholder = <STDIN>;
	chomp($placeholder);
	print color 'reset';
	
	return;
}

sub nosexism {
print colored('>>>>ABEVTUGFSBEJBZRANYYYVOREGVRFSBEZRA>>>>ABEVTUGFSBEJBZRANYYYVOREGVRFSBEZRA>>>>',"$boldblack on_$bgcblack"); print"\n"; 
print colored('Just Say No To Sexism                                                            ',"$boldred on_$bgcblack"); print"\n"; 
print colored('    Just Say No To Sexism                                                        ',"$red on_$bgcblack"); print"\n"; 
print colored('        Just Say No To Sexism                                                    ',"$boldred on_$bgcblack"); print"\n"; 
print colored('            Just Say No To Sexism                                                ',"$red on_$bgcblack"); print"\n"; 
print colored('                Just Say No To Sexism                                            ',"$boldred on_$bgcblack"); print"\n"; 
print colored('                    Just Say No To Sexism                                        ',"$red on_$bgcblack"); print"\n"; 
print colored('                        Just Say No To Sexism                                    ',"$boldred on_$bgcblack"); print"\n"; 
print colored('                            Just Say No To Sexism                                ',"$red on_$bgcblack"); print"\n"; 
print colored('                                Just Say No To Sexism                            ',"$boldred on_$bgcblack"); print"\n"; 
print colored('                                    Just Say No To Sexism                        ',"$red on_$bgcblack"); print"\n"; 
print colored('                                        Just Say No To Sexism                    ',"$boldred on_$bgcblack"); print"\n"; 
print colored('                                            Just Say No To Sexism                ',"$red on_$bgcblack"); print"\n"; 
print colored('                                                Just Say No To Sexism            ',"$boldred on_$bgcblack"); print"\n"; 
print colored('                                                   Just Say No To Sexism         ',"$red on_$bgcblack"); print"\n"; 
print colored('                                                Just Say No To Sexism            ',"$boldred on_$bgcblack"); print"\n"; 
print colored('                                            Just Say No To Sexism                ',"$red on_$bgcblack"); print"\n"; 
print colored('                                        Just Say No To Sexism                    ',"$boldred on_$bgcblack"); print"\n"; 
print colored('                                    Just Say No To Sexism                        ',"$red on_$bgcblack"); print"\n"; 
print colored('                                Just Say No To Sexism                            ',"$boldred on_$bgcblack"); print"\n"; 
print colored('                            Just Say No To Sexism                                ',"$red on_$bgcblack"); print"\n"; 
print colored('                        Just Say No To Sexism                                    ',"$boldred on_$bgcblack"); print"\n"; 
print colored('                    Just Say No To Sexism                                        ',"$red on_$bgcblack"); print"\n"; 
print colored('                Just Say No To Sexism                                            ',"$boldred on_$bgcblack"); print"\n"; 
print colored('            Just Say No To Sexism                                                ',"$red on_$bgcblack"); print"\n"; 
print colored('        Just Say No To Sexism                                                    ',"$boldred on_$bgcblack"); print"\n"; 
print colored('    Just Say No To Sexism                                                        ',"$red on_$bgcblack"); print"\n"; 
print colored('Just Say No To Sexism                                                            ',"$boldred on_$bgcblack"); print"\n"; 
print colored('>>>>ABEVTUGFSBEJBZRANYYYVOREGVRFSBEZRA>>>>ABEVTUGFSBEJBZRANYYYVOREGVRFSBEZRA>>>>',"$boldblack on_$bgcblack"); print"\n"; 
print color 'black';
	$placeholder = <STDIN>;
	chomp($placeholder);
	print color 'reset';
	
	return;
}

sub ptracker {
	if ($playtrack == 1) {
		push @ptracker, "$money";
	} else {
		##Nothing
	}

	if ($banksavmoney > 0) {
		cmpndschedule();
		if ($banksavingintvl >= $banksavcpndintvl) {
			computesverte();
			$banksavintrst = ($banksavmoney * $banksavrte);
			$banksavmoney = $banksavmoney + $banksavintrst;
			##Below we track the interest earned and reset the interval timer
			$banksavintrsttrk = $banksavintrsttrk + $banksavintrst;
			$banksavecrintsttrk = $banksavecrintsttrk + $banksavintrst;
			$banksavingintvl = 0;
		} else {
			$banksavingintvl = $banksavingintvl + 1;
		}
	}

	stockmarket();
}

sub computesverte {
	#What to pay each compound interval.
	#This differs depending on if the interval is larger or smaller than
	#the period (annum) (How often untill account gets full x% interest payed to it.
	$banksavrte = $banktruesavrte * ($banksavcpndintvl/$banksavperiod);
	if ($banksavrte > $banktruesavrte) {
		$banksavrte = $banktruesavrte;
		#If the computed per-interval-period interest rate goes above
		#the true interest rate, even though that is the amount that is due
		#we will discount it down to the true interest rate and treat
		#the compound-interval as the pay period.
	}
	
	##print"!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n";
	##print "$banksavrte".' = '."$banktruesavrte".' * ('."$banksavcpndintvl".'/'."$banksavperiod".')'."\n";
}

sub cmpndschedule {
	$oldbanksavcpndintvl == $banksavcpndintvl;
	
	if ($banksavmoney >= 1000000000) {
		$banksavcpndintvl = 15;
		$banktruesavrte = 0.09;
	} elsif ($banksavmoney >= 100000000) {
		$banksavcpndintvl = 20;
		$banktruesavrte = 0.085;
	} elsif ($banksavmoney >= 10000000) {
		$banksavcpndintvl = 25;
		$banktruesavrte = 0.08;
	} elsif ($banksavmoney >= 5000000) {
		$banksavcpndintvl = 30;
		$banktruesavrte = 0.075;
	} elsif ($banksavmoney >= 2500000) {
		$banksavcpndintvl = 40;
		$banktruesavrte = 0.07;
	} elsif ($banksavmoney >= 1000000) {
		$banksavcpndintvl = 50;
		$banktruesavrte = 0.065;
	} elsif ($banksavmoney >= 500000) {
		$banksavcpndintvl = 100;
		$banktruesavrte = 0.06;
	} elsif ($banksavmoney >= 250000) {
		$banksavcpndintvl = 125;
		$banktruesavrte = 0.055;	
	} elsif ($banksavmoney >= 100000) {
		$banksavcpndintvl = 150;
		$banktruesavrte = 0.05;
	} elsif ($banksavmoney >= 10000) {
		$banksavcpndintvl = 200;
		$banktruesavrte = 0.045;
	} elsif ($banksavmoney >= 7500) {
		$banksavcpndintvl = 500;
		$banktruesavrte = 0.04;
	} elsif ($banksavmoney >= 5000) {
		$banksavcpndintvl = 700;
		$banktruesavrte = 0.03;
	} elsif ($banksavmoney >= 2500) {
		$banksavcpndintvl = 1000;
		$banktruesavrte = 0.03;	
	} elsif ($banksavmoney >= 1000) {
		$banksavcpndintvl = 2000;
		$banktruesavrte = 0.03;
	} elsif ($banksavmoney >= 750) {
		$banksavcpndintvl = 5000;
		$banktruesavrte = 0.03;
	} elsif ($banksavmoney >= 500) {
		$banksavcpndintvl = 7500;
		$banktruesavrte = 0.03;
	} elsif ($banksavmoney >= 250) {
		$banksavcpndintvl = 10000;
		$banktruesavrte = 0.03;
	} elsif ($banksavmoney >= 100) {
		$banksavcpndintvl = 50000;
		$banktruesavrte = 0.03;
	} elsif ($banksavmoney >= 75) {
		$banksavcpndintvl = 100000;
		$banktruesavrte = 0.03;
	} elsif ($banksavmoney >= 50) {
		$banksavcpndintvl = 500000;
		$banktruesavrte = 0.03;
	} elsif ($banksavmoney >= 25) {
		$banksavcpndintvl = 750000;
		$banktruesavrte = 0.03;
	} elsif ($banksavmoney >= 15) {
		$banksavcpndintvl = 1000000;
		$banktruesavrte = 0.03;
	} elsif ($banksavmoney >= 10) {
		$banksavcpndintvl = 5000000;
		$banktruesavrte = 0.03;
	} elsif ($banksavmoney >= 5) {
		$banksavcpndintvl = 10000000;
		$banktruesavrte = 0.03;		
	} else {
		$banksavcpndintvl = 10000000;
		$banktruesavrte = 0.03;
	}
	
	##If we have switched to a better (smaller) interval period, we reset the timer.
	if ($banksavcpndintvl < $oldbanksavcpndintvl) {
		if ($banksavingintvl >= $banksavcpndintvl) {
			##If time left to compound interest is greater or equal
			##to the new compound interest period, we reset the timer.
			$banksavingintvl = 0;
		} else {
			##If the time left to compound the interest is less that
			##the new compound interest period:
			##Do nothing. It is in the best interest of the client
			##that he keep his current interval time.
		}
	}
}

sub stockmarket {
	if ($stockcortick >= $stockcorset) {
		##Time to reevaluate the market
		stockmarketset();
		$stockcortick = 0;
	}
	fundretail();
	fundindustry();
	fundtech();
	fundenergy();
	fundtextile();
	fundinvestment();
	fundlending();
	fundconstruction();
	fundmining();
	fundindex();
	if ($stockmarketdebug == 1) {
		print "$stockmarketwhole\n";
		print "$stockcortick".' of '."$stockcorset\n";
	}
	$stocktick = $stocktick + 1;
	$stockcortick = $stockcortick + 1;
}

sub stockmarketinit {
	$stocktcst = 10; #Flat fee for each buy.
	$stocktcom = 0.10; #Plus commission percentage.
	$stocktcstsl = 6; #Flat fee for each sale.
	$stocktax = 0.05; #Cap-gains tax.
	$stocktick = 0; #Stock market clock.
	$stockcortick = 0; #Market correction tick
	$stockcorset = int(rand(100000)) + 5000; #How many ticks before market correction?
	@stockmarketwholetypes = ('volatile',
	                     'mid',
			     'okgood',
			     'okbad',
			     'good',
			     'bad',
			     'great',
			     'terrible',);
	stockmarketset(); #Set what kind of market we're in (Bull, Bear, Neither, MegaBull, Incredi-Bear
	$stockbuff0 = '';
	$stockbuff1 = '';
	$stockbuff2 = '';
	$stockbuff3 = '';
	$stockmarketdebug = 0; #Print Stockmarket info on each turn?
	##Retail Stocks Fund
	$fundretailshares = 0; #Shares player owns of fund.
	$fundretailsharevalue = rand(100); #Value of each share.
	$fundretailmode = int(rand(2)+4); # What mode the fund is in, gaining or losing, how badly.
	$fundretailmarket = @stockmarkettypes[(int(rand(@stockmarkettypes)))];
	@fundretailtracker = ("$fundretailsharevalue");
	$fundretailcortick = 0;
	$fundretailcorset = int(rand(10000)) + 500; #How many ticks before sector correction?
	##Industrial Stocks Fund
	$fundindustryshares = 0; #Shares player owns of fund.
	$fundindustrysharevalue = rand(200); #Value of each share.
	$fundindustrymode = int(rand(2)+4); # What mode the fund is in, gaining or losing, how badly.
	$fundindustrymarket = @stockmarkettypes[(int(rand(@stockmarkettypes)))];
	@fundindustrytracker = ("$fundindustrysharevalue");
	$fundindustrycortick = 0;
	$fundindustrycorset = int(rand(50000)) + 5000; #How many ticks before sector correction?
	##Tech Stock Fund
	$fundtechshares = 0; #Shares player owns of fund.
	$fundtechsharevalue = rand(300); #Value of each share.
	$fundtechmode = int(rand(2)+4); # What mode the fund is in, gaining or losing, how badly.
	$fundtechmarket = @stockmarkettypes[(int(rand(@stockmarkettypes)))];
	@fundtechtracker = ("$fundtechsharevalue");
	$fundtechcortick = 0;
	$fundtechcorset = int(rand(1000)) + 100; #How many ticks before sector correction?
	##Energy Stock
	$fundenergyshares = 0; #Shares player owns of fund.
	$fundenergysharevalue = rand(1000); #Value of each share.
	$fundenergymode = int(rand(2)+4); # What mode the fund is in, gaining or losing, how badly.
	$fundenergymarket = @stockmarkettypes[(int(rand(@stockmarkettypes)))];
	@fundenergytracker = ("$fundenergysharevalue");
	$fundenergycortick = 0;
	$fundenergycorset = int(rand(10000)) + 1000; #How many ticks before sector correction?
	##Textile Stocks Fund
	$fundtextileshares = 0; #Shares player owns of fund.
	$fundtextilesharevalue = rand(40); #Value of each share.
	$fundtextilemode = int(rand(2)+4); # What mode the fund is in, gaining or losing, how badly.
	$fundtextilemarket = @stockmarkettypes[(int(rand(@stockmarkettypes)))];
	@fundtextiletracker = ("$fundtextilesharevalue");
	$fundtextilecortick = 0;
	$fundtextilecorset = int(rand(3000)) + 1000; #How many ticks before sector correction?
	##Investement Bank Stocks Fund
	$fundinvestmentshares = 0; #Shares player owns of fund.
	$fundinvestmentsharevalue = rand(2000); #Value of each share.
	$fundinvestmentmode = int(rand(2)+4); # What mode the fund is in, gaining or losing, how badly.
	$fundinvestmentmarket = @stockmarkettypes[(int(rand(@stockmarkettypes)))];
	@fundinvestmenttracker = ("$fundinvestmentsharevalue");
	$fundinvestmentcortick = 0;
	$fundinvestmentcorset = int(rand(1000)) + 300; #How many ticks before sector correction?
	##Lending Institution Stocks Fund
	$fundlendingshares = 0; #Shares player owns of fund.
	$fundlendingsharevalue = rand(100); #Value of each share.
	$fundlendingmode = int(rand(2)+4); # What mode the fund is in, gaining or losing, how badly.
	$fundlendingmarket = @stockmarkettypes[(int(rand(@stockmarkettypes)))];
	@fundlendingtracker = ("$fundlendingsharevalue");
	$fundlendingcortick = 0;
	$fundlendingcorset = int(rand(5000)) + 2000; #How many ticks before sector correction?
	##Construction Stocks Fund
	$fundconstructionshares = 0; #Shares player owns of fund.
	$fundconstructionsharevalue = rand(100); #Value of each share.
	$fundconstructionmode = int(rand(2)+4); # What mode the fund is in, gaining or losing, how badly.
	$fundconstructionmarket = @stockmarkettypes[(int(rand(@stockmarkettypes)))];
	@fundconstructiontracker = ("$fundconstructionsharevalue");
	$fundconstructioncortick = 0;
	$fundconstructioncorset = int(rand(1000)) + 1000; #How many ticks before sector correction?
	##Mining Stocks Fund
	$fundminingshares = 0; #Shares player owns of fund.
	$fundminingsharevalue = rand(100000); #Value of each share.
	$fundminingmode = int(rand(2)+4); # What mode the fund is in, gaining or losing, how badly.
	$fundminingmarket = @stockmarkettypes[(int(rand(@stockmarkettypes)))];
	@fundminingtracker = ("$fundminingsharevalue");
	$fundminingcortick = 0;
	$fundminingcorset = int(rand(2500)) + 500; #How many ticks before sector correction?
	##Index Fund
	#Originally: 50000000000, 50000000000, 200000000000
	if ($money >= 10000000000000000000000000000000000000000000000000) {
		$fundindexinvestper = int(rand(50000000000000000000000000000000000000000000000000000000)) + 50000000000000000000000000000000000000000000000000000000; #How much the index fund invests into each sector
		$fundnrmlz = int(rand(200000000000000000000000000000000000000000000000000000000)); #How much to divide the final number by to get initial share price
	} elsif ($money >= 10000000000000000000000000000000000000000000000) {
		$fundindexinvestper = int(rand(50000000000000000000000000000000000000000000000000000)) + 50000000000000000000000000000000000000000000000000000; #How much the index fund invests into each sector
		$fundnrmlz = int(rand(200000000000000000000000000000000000000000000000000000)); #How much to divide the final number by to get initial share price
	} elsif ($money >= 10000000000000000000000000000000000000000000) {
		$fundindexinvestper = int(rand(50000000000000000000000000000000000000000000000000)) + 50000000000000000000000000000000000000000000000000; #How much the index fund invests into each sector
		$fundnrmlz = int(rand(200000000000000000000000000000000000000000000000000)); #How much to divide the final number by to get initial share price
	} elsif ($money >= 10000000000000000000000000000000000000000) {
		$fundindexinvestper = int(rand(50000000000000000000000000000000000000000000000)) + 50000000000000000000000000000000000000000000000; #How much the index fund invests into each sector
		$fundnrmlz = int(rand(200000000000000000000000000000000000000000000000)); #How much to divide the final number by to get initial share price
	} elsif ($money >= 10000000000000000000000000000000000000) {
		$fundindexinvestper = int(rand(50000000000000000000000000000000000000000000)) + 50000000000000000000000000000000000000000000; #How much the index fund invests into each sector
		$fundnrmlz = int(rand(200000000000000000000000000000000000000000000)); #How much to divide the final number by to get initial share price
	} elsif ($money >= 10000000000000000000000000000000000) {
		$fundindexinvestper = int(rand(50000000000000000000000000000000000000000)) + 50000000000000000000000000000000000000000; #How much the index fund invests into each sector
		$fundnrmlz = int(rand(200000000000000000000000000000000000000000)); #How much to divide the final number by to get initial share price
	} elsif ($money >= 10000000000000000000000000000000) {
		$fundindexinvestper = int(rand(50000000000000000000000000000000000000)) + 50000000000000000000000000000000000000; #How much the index fund invests into each sector
		$fundnrmlz = int(rand(200000000000000000000000000000000000000)); #How much to divide the final number by to get initial share price
	} elsif ($money >= 10000000000000000000000000000) {
		$fundindexinvestper = int(rand(50000000000000000000000000000000000)) + 50000000000000000000000000000000000; #How much the index fund invests into each sector
		$fundnrmlz = int(rand(200000000000000000000000000000000000)); #How much to divide the final number by to get initial share price
	} elsif ($money >= 10000000000000000000000000) {
		$fundindexinvestper = int(rand(50000000000000000000000000000000)) + 50000000000000000000000000000000; #How much the index fund invests into each sector
		$fundnrmlz = int(rand(200000000000000000000000000000000)); #How much to divide the final number by to get initial share price
	} elsif ($money >= 10000000000000000000000) {
		$fundindexinvestper = int(rand(50000000000000000000000000000)) + 50000000000000000000000000000; #How much the index fund invests into each sector
		$fundnrmlz = int(rand(200000000000000000000000000000)); #How much to divide the final number by to get initial share price
	} elsif ($money >= 10000000000000000000) {
		$fundindexinvestper = int(rand(50000000000000000000000000)) + 50000000000000000000000000; #How much the index fund invests into each sector
		$fundnrmlz = int(rand(200000000000000000000000000)); #How much to divide the final number by to get initial share price
	} elsif ($money >= 10000000000000000) {
		$fundindexinvestper = int(rand(50000000000000000000000)) + 50000000000000000000000; #How much the index fund invests into each sector
		$fundnrmlz = int(rand(200000000000000000000000)); #How much to divide the final number by to get initial share price
	} elsif ($money >= 10000000000000) {
		$fundindexinvestper = int(rand(50000000000000000000)) + 50000000000000000000; #How much the index fund invests into each sector
		$fundnrmlz = int(rand(200000000000000000000)); #How much to divide the final number by to get initial share price
	} elsif ($money >= 10000000000) {
		$fundindexinvestper = int(rand(50000000000000000)) + 50000000000000000; #How much the index fund invests into each sector
		$fundnrmlz = int(rand(200000000000000000)); #How much to divide the final number by to get initial share price
	} else {
		$fundindexinvestper = int(rand(50000000000)) + 50000000000; #How much the index fund invests into each sector
		$fundnrmlz = int(rand(200000000000)); #How much to divide the final number by to get initial share price	
	}
	$fundindexretail = floor($fundindexinvestper/$fundretailsharevalue); #How many shares of a sector the fund has purchased at the begining.
	$fundindexindustry = floor($fundindexinvestper/$fundindustrysharevalue); 
	$fundindextech = floor($fundindexinvestper/$fundtechsharevalue);
	$fundindexenergy = floor($fundindexinvestper/$fundenergysharevalue);
	$fundindextextile = floor($fundindexinvestper/$fundtextilesharevalue);
	$fundindexinvestment = floor($fundindexinvestper/$fundinvestmentsharevalue);
	$fundindexlending = floor($fundindexinvestper/$fundlendingsharevalue); 
	$fundindexconstruction = floor($fundindexinvestper/$fundconstructionsharevalue); 
	$fundindexmining = floor($fundindexinvestper/$fundminingsharevalue);
	
	$fundindexshares = 0;
	fundindexvalue();
	fundindexinitvalue();
	@fundindextracker = ("$fundindexsharevalue");
	$fundindexcortick = 0;
}

sub fundretail {
	if ($fundretailcortick >= $fundretailcorset) {
		##Time to reevaluate the sector.
		$fundretailmarket = @stockmarkettypes[(int(rand(@stockmarkettypes)))];
		$fundretailcortick = 0;
	}
	$stockbuff0 = $fundretailmode;
	
	if (2 >= $fundlendingmode) {
		$fundretailmode = $fundretailmode - 1;
		if (0 >= $fundretailmode) {
			$fundretailmode = 0;
		}
		#If Lending is down, retail is down.
	}
	
	if ($fundlendingmode >= 8) {
		$fundretailmode = $fundretailmode + int(rand(2)) + 1;
		if ($fundretailmode >= 10) {
			$fundretailmode = 10;
		}
		#If Lending is up, retail is up.
	}
	
	sharevalue(); #Writes to $stockbuff1
	$stockbuff2 = $fundretailmarket;
	fundmode(); #Writes to $stockbuff0
	$fundretailsharevalue = $fundretailsharevalue * ($stockbuff1);
	$fundretailmode = $stockbuff0;
	push @fundretailtracker, "$fundretailsharevalue";
	
	if ($stockmarketdebug == 1) {
		print "Retail\n";
		print "$fundretailsharevalue\n";
		print "$fundretailmode\n";
		print "$fundretailmarket\n";
		print "$fundretailcorset\n\n";
	}
}

sub fundindustry {
	if ($fundindustrycortick >= $fundindustrycorset) {
		##Time to reevaluate the sector.
		$fundindustrymarket = @stockmarkettypes[(int(rand(@stockmarkettypes)))];
		$fundindustrycortick = 0;
	}
	$stockbuff0 = $fundindustrymode;
	sharevalue(); #Writes to $stockbuff1
	$stockbuff2 = $fundindustrymarket;
	fundmode(); #Writes to $stockbuff0
	$fundindustrysharevalue = $fundindustrysharevalue * ($stockbuff1);
	$fundindustrymode = $stockbuff0;
	push @fundindustrytracker, "$fundindustrysharevalue";
	
	if ($stockmarketdebug == 1) {
		print "$fundindustrysharevalue\n";
		print "$fundindustrymode\n";
		print "$fundindustrymarket\n";
		print "$fundindustrycorset\n\n";
	}
}

sub fundtech {
	if ($fundtechcortick >= $fundtechcorset) {
		##Time to reevaluate the sector.
		$fundtechmarket = @stockmarkettypes[(int(rand(@stockmarkettypes)))];
		$fundtechcortick = 0;
	}
	$stockbuff0 = $fundtechmode;
	sharevalue(); #Writes to $stockbuff1
	$stockbuff2 = $fundtechmarket;
	fundmode(); #Writes to $stockbuff0
	$fundtechsharevalue = $fundtechsharevalue * ($stockbuff1);
	$fundtechmode = $stockbuff0;
	push @fundtechtracker, "$fundtechsharevalue";
	
	if ($stockmarketdebug == 1) {
		print "Tech\n";
		print "$fundtechsharevalue\n";
		print "$fundtechmode\n";
		print "$fundtechmarket\n";
		print "$fundtechcorset\n\n";
	}
}

sub fundenergy {
	if ($fundenergycortick >= $fundenergycorset) {
		##Time to reevaluate the sector.
		$fundenergymarket = @stockmarkettypes[(int(rand(@stockmarkettypes)))];
		$fundenergycortick = 0;
	}
	$stockbuff0 = $fundenergymode;
	sharevalue(); #Writes to $stockbuff1
	$stockbuff2 = $fundenergymarket;
	fundmode(); #Writes to $stockbuff0
	$fundenergysharevalue = $fundenergysharevalue * ($stockbuff1);
	$fundenergymode = $stockbuff0;
	push @fundenergytracker, "$fundenergysharevalue";
	
	if ($stockmarketdebug == 1) {
		print "Energy\n";
		print "$fundenergysharevalue\n";
		print "$fundenergymode\n";
		print "$fundenergymarket\n";
		print "$fundenergycorset\n\n";
	}
}

sub fundtextile {
	if ($fundtextilecortick >= $fundtextilecorset) {
		##Time to reevaluate the sector.
		$fundtextilemarket = @stockmarkettypes[(int(rand(@stockmarkettypes)))];
		$fundtextilecortick = 0;
	}
	$stockbuff0 = $fundtextilemode;
	sharevalue(); #Writes to $stockbuff1
	$stockbuff2 = $fundtextilemarket;
	fundmode(); #Writes to $stockbuff0
	$fundtextilesharevalue = $fundtextilesharevalue * ($stockbuff1);
	$fundtextilemode = $stockbuff0;
	push @fundtextiletracker, "$fundtextilesharevalue";
	
	if ($stockmarketdebug == 1) {
		print "Textile\n";
		print "$fundtextilesharevalue\n";
		print "$fundtextilemode\n";
		print "$fundtextilemarket\n";
		print "$fundtextilecorset\n\n";
	}
}

sub fundinvestment {
	if ($fundinvestmentcortick >= $fundinvestmentcorset) {
		##Time to reevaluate the sector.
		$fundinvestmentmarket = @stockmarkettypes[(int(rand(@stockmarkettypes)))];
		$fundinvestmentcortick = 0;
	}
	$stockbuff0 = $fundinvestmentmode;
	sharevalue(); #Writes to $stockbuff1
	$stockbuff2 = $fundinvestmentmarket;
	fundmode(); #Writes to $stockbuff0
	$fundinvestmentsharevalue = $fundinvestmentsharevalue * ($stockbuff1);
	$fundinvestmentmode = $stockbuff0;
	push @fundinvestmenttracker, "$fundinvestmentsharevalue";
	
	if ($stockmarketdebug == 1) {
		print "Investment\n";
		print "$fundinvestmentsharevalue\n";
		print "$fundinvestmentmode\n";
		print "$fundinvestmentmarket\n";
		print "$fundinvestmentcorset\n\n";
	}
}

sub fundlending {
	if ($fundlendingcortick >= $fundlendingcorset) {
		##Time to reevaluate the sector.
		$fundlendingmarket = @stockmarkettypes[(int(rand(@stockmarkettypes)))];
		$fundlendingcortick = 0;
	}
	$stockbuff0 = $fundlendingmode;
	sharevalue(); #Writes to $stockbuff1
	$stockbuff2 = $fundlendingmarket;
	fundmode(); #Writes to $stockbuff0
	$fundlendingsharevalue = $fundlendingsharevalue * ($stockbuff1);
	$fundlendingmode = $stockbuff0;
	push @fundlendingtracker, "$fundlendingsharevalue";
	
	if ($stockmarketdebug == 1) {
		print "Lending\n";
		print "$fundlendingsharevalue\n";
		print "$fundlendingmode\n";
		print "$fundlendingmarket\n";
		print "$fundlendingcorset\n\n";
	}
}

sub fundconstruction {
	if ($fundconstructioncortick >= $fundconstructioncorset) {
		##Time to reevaluate the sector.
		$fundconstructionmarket = @stockmarkettypes[(int(rand(@stockmarkettypes)))];
		$fundconstructioncortick = 0;
	}
	$stockbuff0 = $fundconstructionmode;
	
	if (2 >= $fundlendingmode) {
		$fundconstructionmode = $fundconstructionmode - int(rand(2)) + 1;
		if (0 >= $fundconstructionmode) {
			$fundconstructionmode = 0;
		}
		#If Lending is down, construction is down.
	}
	
	if ($fundlendingmode >= 9) {
		$fundconstructionmode = $fundconstructionmode + 1;
		if ($fundconstructionmode >= 10) {
			$fundconstructionmode = 10;
		}
		#If Lending is REALLY up, construction is up.
	}
	
	sharevalue(); #Writes to $stockbuff1
	$stockbuff2 = $fundconstructionmarket;
	fundmode(); #Writes to $stockbuff0
	$fundconstructionsharevalue = $fundconstructionsharevalue * ($stockbuff1);
	$fundconstructionmode = $stockbuff0;
	push @fundconstructiontracker, "$fundconstructionsharevalue";
	
	if ($stockmarketdebug == 1) {
		print "Construction\n";
		print "$fundconstructionsharevalue\n";
		print "$fundconstructionmode\n";
		print "$fundconstructionmarket\n";
		print "$fundconstructioncorset\n\n";
	}
}

sub fundmining {
	if ($fundminingcortick >= $fundminingcorset) {
		##Time to reevaluate the sector.
		$fundminingmarket = @stockmarkettypes[(int(rand(@stockmarkettypes)))];
		$fundminingcortick = 0;
	}
	$stockbuff0 = $fundminingmode;
	
	if ((2 >= $fundlendingmode) and ($fundinvestmentmode >= 7)) {
		$fundminingmode = $fundminingmode + 1;
		if ($fundminingmode >= 10) {
			$fundminingmode = 10;
		}
		#If Lending is down, but investment is somewhat up, mining is up.
	}
	
	if ($fundindustrymode >= 8) {
		$fundminingmode = $fundminingmode + int(rand(2)) + 1;
		if ($fundminingmode >= 10) {
			$fundminingmode = 10;
		}
		#If Industry is up, mining is up.
	}
	
	if ((2 >= $fundlendingmode) and (3 >= $fundretailmode)) {
		$fundminingmode = $fundminingmode - 1;
		if (0 >= $fundminingmode) {
			$fundminingmode = 0;
		}
		#If Lending is down, and retail is somewhat down, mining is down.
		if (2 >= $fundinvestmentmode) {
			$fundminingmode = $fundminingmode - 1;
			if (0 >= $fundminingmode) {
				$fundminingmode = 0;
			}
			#If Investment is down aswell, mining is more depressed
			#(only gold mining would be up, most other mining down)
		}
	}
	
	sharevalue(); #Writes to $stockbuff1
	$stockbuff2 = $fundminingmarket;
	fundmode(); #Writes to $stockbuff0
	$fundminingsharevalue = $fundminingsharevalue * ($stockbuff1);
	$fundminingmode = $stockbuff0;
	push @fundminingtracker, "$fundminingsharevalue";
	
	if ($stockmarketdebug == 1) {
		print "Mining\n";
		print "$fundminingsharevalue\n";
		print "$fundminingmode\n";
		print "$fundminingmarket\n";
		print "$fundminingcorset\n\n";
	}
}

sub fundindex {
	fundindexvalue();
	push @fundindextracker, "$fundindexsharevalue";
	
	if ($stockmarketdebug == 1) {
		print "Index::\n";
		print "$fundindexsharevalue\n";
		print "$fundindexcortick\n\n";
		print "$fundindexretail\n"
			."$fundindexindustry\n"
			."$fundindextech\n"
			."$fundindexenergy\n"
			."$fundindextextile\n"
			."$fundindexinvestment\n"
			."$fundindexlending\n"
			."$fundindexconstruction\n"
			."$fundindexmining\n";
	}
}

sub fundindexvalue {
	$fundindexsharevalue = ((($fundindexretail * $fundretailsharevalue)
				+ ($fundindexindustry * $fundindustrysharevalue)
				+ ($fundindextech * $fundtechsharevalue)
				+ ($fundindexenergy * $fundenergysharevalue)
				+ ($fundindextextile * $fundtextilesharevalue)
				+ ($fundindexinvestment * $fundinvestmentsharevalue)
				+ ($fundindexlending * $fundlendingsharevalue)
				+ ($fundindexconstruction * $fundconstructionsharevalue)
				+ ($fundindexmining * $fundminingsharevalue)) / $fundnrmlz);
}

sub fundindexinitvalue {
	#Just Records the inital value of these 
	@fundindexvalueinit = (($fundindexretail * $fundretailsharevalue),
				($fundindexindustry * $fundindustrysharevalue),
				($fundindextech * $fundtechsharevalue),
				($fundindexenergy * $fundenergysharevalue),
				($fundindextextile * $fundtextilesharevalue),
				($fundindexinvestment * $fundinvestmentsharevalue),
				($fundindexlending * $fundlendingsharevalue),
				($fundindexconstruction * $fundconstructionsharevalue),
				($fundindexmining * $fundminingsharevalue));
	
	if ($stockmarketdebug == 1) {
		foreach (@fundindexvalueinit) {
			print"!!!!!!!!!!!!!!!!!!!!! $_ \n"	
		}
	}
}

sub stockmarketset {
	$stockmarketwhole = @stockmarketwholetypes[(int(rand(@stockmarketwholetypes)))];
	if($stockmarketwhole eq 'volatile') {
		@stockmarkettypes = ('midmarket',
		                     'upmarket',
			             'downmarket',);
	} elsif($stockmarketwhole eq 'mid') {
		@stockmarkettypes = ('midmarket',
		                     'midmarket',
				     'midmarket',
				     'midmarket',
		                     'midmarket',
				     'midmarket',
				     'upmarket',
				     'upmarket',
			             'downmarket',
			             'downmarket',);
	} elsif($stockmarketwhole eq 'okgood') {
		@stockmarkettypes = ('midmarket',
		                     'midmarket',
				     'midmarket',
				     'midmarket',
				     'midmarket',
				     'midmarket',
				     'midmarket',
		                     'upmarket',
				     'upmarket',
				     'upmarket',
			             'downmarket',
			             'downmarket',);
	} elsif($stockmarketwhole eq 'okbad') {
		@stockmarkettypes = ('midmarket',
		                     'midmarket',
				     'midmarket',
				     'midmarket',
				     'midmarket',
				     'midmarket',
				     'midmarket',
				     'upmarket',
			             'upmarket',
		                     'downmarket',
				     'downmarket',
			             'downmarket',);
	} elsif($stockmarketwhole eq 'good') {
		@stockmarkettypes = ('midmarket',
		                     'midmarket',
				     'midmarket',
				     'midmarket',
		                     'upmarket',
				     'upmarket',
				     'upmarket',
			             'downmarket',);
	} elsif($stockmarketwhole eq 'bad') {
		@stockmarkettypes = ('midmarket',
		                     'midmarket',
				     'midmarket',
				     'midmarket',
				     'upmarket',
		                     'downmarket',
				     'downmarket',
				     'downmarket',
			             'downmarket',);
	} elsif($stockmarketwhole eq 'great') {
		@stockmarkettypes = ('midmarket',
		                     'midmarket',
				     'midmarket',
				     'midmarket',
				     'upmarket',
		                     'upmarket',
				     'upmarket',
				     'upmarket',
			             'upmarket',
				     'downmarket',
			             'downmarket',);
	} elsif($stockmarketwhole eq 'terrible') {
		@stockmarkettypes = ('midmarket',
		                     'midmarket',
				     'midmarket',
				     'downmarket',
		                     'downmarket',
				     'downmarket',
				     'downmarket',
			             'upmarket',
			             'downmarket',
				     'downdownmarket',
			             'downdownmarket',);
	} else {
		@stockmarkettypes = ('midmarket',
		                     'midmarket',
				     'midmarket',);
	}	
}

sub sharevalue {
	##Decideds if stock value will go up or down.
	if ($stockbuff0 == 0) {
		$stockbuff1 = ((0.9999) - (rand(0.0005)));
	} elsif ($stockbuff0 == 1) {
		$stockbuff1 = ((1) - (rand(0.0005)));
	} elsif ($stockbuff0 == 2) {
		$stockbuff1 = ((1) - (rand(0.0004)));
	} elsif ($stockbuff0 == 3) {
		$stockbuff1 = ((1) - (rand(0.0003)));
	} elsif ($stockbuff0 == 4) {
		$stockbuff1 = ((1) - (rand(0.0002)));
	} elsif ($stockbuff0 == 5) {
		#Midpoint
		$stockbuff1 = (rand(0.0002))+(0.9999);
		#Midpoint
	} elsif ($stockbuff0 == 6) {
		$stockbuff1 = (rand(0.0002))+(1);
	} elsif ($stockbuff0 == 7) {
		$stockbuff1 = (rand(0.0003))+(1);
	} elsif ($stockbuff0 == 8) {
		$stockbuff1 = (rand(0.0004))+(1);
	} elsif ($stockbuff0 == 9) {
		$stockbuff1 = (rand(0.0005))+(1);
	} elsif ($stockbuff0 == 10) {
		$stockbuff1 = (rand(0.0005))+(1.0001);
	} else {
		##Shouldn't Happen
		$stockbuff1 = (rand(0.0002))+(0.9999); #Midpoint
	}
}

sub fundmode {
	if ($stockbuff2 eq 'midmarket') {
		midmarket();
	} elsif ($stockbuff2 eq 'upmarket') {
		upmarket();
	} elsif ($stockbuff2 eq 'downmarket') {
		downmarket();
	} elsif ($stockbuff2 eq 'upupmarket') {
		upupmarket();
	} elsif ($stockbuff2 eq 'downdownmarket') {
		downdownmarket();
	} else {
		midmarket();
	}
	
	$stockbuff0 = @stockbuffa0[(int(rand(@stockbuffa0)))];
	
	##Just incase, Shouldn't be needed.
	if ($stockbuff0 > 10) {
		$stockbuff0 == 10;
	} elsif ($stockbuff0 < 0) {
		$stockbuff0 == 0;
	}
}

sub midmarket {
	#Decides if fund will enter new mode.
	$stockbuff2 = ($stockbuff0 - 1);
	$stockbuff3 = ($stockbuff0 + 1);
	if ($stockbuff0 == 0) {
		@stockbuffa0 =
		("$stockbuff3",
		"$stockbuff3",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff3",
		"$stockbuff3");
	} elsif ($stockbuff0 == 10) {
		@stockbuffa0 =
		("$stockbuff2",
		"$stockbuff2",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff2",
		"$stockbuff2");	
	} elsif (($stockbuff0 == 1) or ($stockbuff0 == 9)) {
		@stockbuffa0 =
		("$stockbuff2",
		"$stockbuff2",
		"$stockbuff2",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff3",
		"$stockbuff3",
		"$stockbuff3");
	} else {
		@stockbuffa0 =
		("$stockbuff2",
		"$stockbuff2",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff3",
		"$stockbuff3");
	}
}

sub downmarket {
	#Decides if fund will enter new mode.
	$stockbuff2 = ($stockbuff0 - 1);
	$stockbuff3 = ($stockbuff0 + 1);
	if ($stockbuff0 == 0) {
		@stockbuffa0 =
		("$stockbuff3",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff3");
	} elsif ($stockbuff0 == 10) {
		@stockbuffa0 =
		("$stockbuff2",
		"$stockbuff2",
		"$stockbuff2",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff2",
		"$stockbuff2",
		"$stockbuff2");	
	} elsif (($stockbuff0 == 1) or ($stockbuff0 == 9)) {
		@stockbuffa0 =
		("$stockbuff2",
		"$stockbuff2",
		"$stockbuff2",
		"$stockbuff2",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff3",
		"$stockbuff3",
		"$stockbuff3");
	} else {
		@stockbuffa0 =
		("$stockbuff2",
		"$stockbuff2",
		"$stockbuff2",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff3",
		"$stockbuff3");
	}
}

sub upmarket {
	#Decides if fund will enter new mode.
	$stockbuff2 = ($stockbuff0 - 1);
	$stockbuff3 = ($stockbuff0 + 1);
	if ($stockbuff0 == 0) {
		@stockbuffa0 =
		("$stockbuff3",
		"$stockbuff3",
		"$stockbuff3",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff3",
		"$stockbuff3",
		"$stockbuff3");
	} elsif ($stockbuff0 == 10) {
		@stockbuffa0 =
		("$stockbuff2",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff2");	
	} elsif (($stockbuff0 == 1) or ($stockbuff0 == 9)) {
		@stockbuffa0 =
		("$stockbuff2",
		"$stockbuff2",
		"$stockbuff2",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff3",
		"$stockbuff3",
		"$stockbuff3",
		"$stockbuff3");
	} else {
		@stockbuffa0 =
		("$stockbuff2",
		"$stockbuff2",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff3",
		"$stockbuff3",
		"$stockbuff3");
	}
}

sub downdownmarket {
	#Decides if fund will enter new mode.
	$stockbuff2 = ($stockbuff0 - 1);
	$stockbuff3 = ($stockbuff0 + 1);
	if ($stockbuff0 == 0) {
		@stockbuffa0 =
		("$stockbuff3",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff3");
	} elsif ($stockbuff0 == 10) {
		@stockbuffa0 =
		("$stockbuff2",
		"$stockbuff2",
		"$stockbuff2",
		"$stockbuff2",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff2",
		"$stockbuff2",
		"$stockbuff2",
		"$stockbuff2");	
	} elsif (($stockbuff0 == 1) or ($stockbuff0 == 9)) {
		@stockbuffa0 =
		("$stockbuff2",
		"$stockbuff2",
		"$stockbuff2",
		"$stockbuff2",
		"$stockbuff2",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff3",
		"$stockbuff3",
		"$stockbuff3");
	} else {
		@stockbuffa0 =
		("$stockbuff2",
		"$stockbuff2",
		"$stockbuff2",
		"$stockbuff2",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff3",
		"$stockbuff3");
	}
}

sub upupmarket {
	#Decides if fund will enter new mode.
	$stockbuff2 = ($stockbuff0 - 1);
	$stockbuff3 = ($stockbuff0 + 1);
	if ($stockbuff0 == 0) {
		@stockbuffa0 =
		("$stockbuff3",
		"$stockbuff3",
		"$stockbuff3",
		"$stockbuff3",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff3",
		"$stockbuff3",
		"$stockbuff3",
		"$stockbuff3");
	} elsif ($stockbuff0 == 10) {
		@stockbuffa0 =
		("$stockbuff2",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff2");	
	} elsif (($stockbuff0 == 1) or ($stockbuff0 == 9)) {
		@stockbuffa0 =
		("$stockbuff2",
		"$stockbuff2",
		"$stockbuff2",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff3",
		"$stockbuff3",
		"$stockbuff3",
		"$stockbuff3",
		"$stockbuff3");
	} else {
		@stockbuffa0 =
		("$stockbuff2",
		"$stockbuff2",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff0",
		"$stockbuff3",
		"$stockbuff3",
		"$stockbuff3",
		"$stockbuff3");
	}
}

################################################################################################################################
## GENRE: Slot Mahine
## NAME: House Rules Reel Deal
## AUTHOR: MikeeUSA

sub main {
	resethrvars();
	spinreel();
	reeltrans();
	#print"$hrrandnums\n"; #<-- Used for testing purposes, keep commented out <--
	$x = "$svslot1"."$svslot2"."$svslot3";
	
	if ($animate == 1) {
		$reelspin = 3;	
		topscreen();
		mainscreen();
		displaywin();
		smallpause();
		newlines();
		
		$reelspin = 2;	
		topscreen();
		mainscreen();
		displaywin();
		smallpause();
		newlines();
		
		$reelspin = 1;	
		topscreen();
		mainscreen();
		displaywin();
		smallpause();
		newlines();
	}
		
	$reelspin = 0;	
	addmoney();
	fundcalc();
	topscreen();
	mainscreen();
	displaywin();
	ptracker();
	startinfo();
}

sub main2 {
	resethrvars();
	$x = ' ';
	reeltrans();
	topscreen();
	mainscreen();
	##addmoney(); #no reason for this to be here, what was I thinking? Don't uncomment.
	resethrvars();
		if ($startreel == 1) {
			$startreel = 0;
			$addmoney = 0;
		} else {
		}
	displaywin();
	startinfo();
}

sub resethrvars {
	$addmoney = 0;
	$anybar = 0;
	$anybar1 = 0;
	$anybar2 = 0;
	$anybar3 = 0;
	$anycherry = 0;
	$anycherry1 = 0;
	$anycherry2 = 0;
	$anycherry3 = 0;
	$onecherry = 0;
	$nonep = 0;
	$anydollar = 0;
	$anydollar1 = 0;
	$anydollar2 = 0;
	$anydollar3 = 0;
	$reelspin = 0;
} 

sub startinfo {
	tokeneval();
	$startinfo = <STDIN>;
	chomp($startinfo);
	
	if (($startinfo eq 'a') or ($startinfo eq 'A')) {
		$startinfo = $hragaincmd;
	} elsif (($startinfo eq 'p') or ($startinfo eq 'P') or ($startinfo eq '1p') or ($startinfo eq '1P')) {
		$hragaincmd = $startinfo;
	} else {
		#Do Nothing		
	}
	
	if (($startinfo eq 'p') or ($startinfo eq 'P') or ($startinfo eq '1p') or ($startinfo eq '1P')) {
		if ($money >= $coin) {
			$money = $money - $coin;
			$moneyexp = $moneyexp + $coin;
			$hrstmc2 = $hrstmc2 + $coin;
			$spins = $spins + 1;
			$hrstspins = $hrstspins + 1;
			$hrbulbcolor = 'null';
			if ($proadd == 1) {
				$projkpot = $projkpot + $coin;
				$proadd = 0;
			} else {
				$proadd = 1;
			}
			if ($hrrandnums > 103) { 
				if ($hrbonus > 0) {
					$hrbonus = $hrbonus - 1;
				}
				if ($hrbonushlp > 0) {
					$hrbonushlp = $hrbonushlp - 1;
				} elsif ($hrbonushlp == 0) {
					$hrrandnums = 107;
				} elsif ($hrbonushlp < 0) {
					$hrbonushlp = 0;
					$hrrandnums = 107;
				}
			}
			newlines();
			main();
		} else {
			newlines();
			main2();		
		}	
	} elsif (($startinfo eq 'exit') or ($startinfo eq 'EXIT') or ($startinfo eq 'quit') or ($startinfo eq 'QUIT')) {
		exitgame();
	} elsif (($startinfo eq 'c') or ($startinfo eq 'C')) {
		return;			
	} else {
		newlines();
		main2();
	}

}

sub newlines {
	if ($compatVT100 == 1) {
		print"\033[2J\n";
	} else {
		print"\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n";	
	}
}

sub testmusic {
   	if ($music == 1) {
		if (system("$musicplayer -v $musictermquiet")) {
               		$music = 0;
               	} else {
               		$music = 1;
                }
        }
}

sub beginmusic {
	if ($music == 1) {
		$mkillpid = fork();
		unless ($mkillpid) {
			playmusic();
			exit();
		}
	}
}

sub rrbeginmusic {
	if ($music == 1) {
		$mkillpid = fork();
		unless ($mkillpid) {
			rrplaymusic();
			exit();
		}
	}
}

sub bankbeginmusic {
	if ($music == 1) {
		$mkillpid = fork();
		unless ($mkillpid) {
			bankplaymusic();
			exit();
		}
	}
}

sub playmusic {
	if ($music == 1) {
		$SIG{INT} = sub { exit(); };
		#system("$musicplayer $musicvolumecmd$musicvolume $musicdir@musicfiles[0] $musictermquiet");
		while ($music == 1) {
			system("$musicplayer $musicvolumecmd$musicvolume $musicdir@musicfiles[(int(rand(@musicfiles)))] $musictermquiet");
		}
	}
}

sub rrplaymusic {
	if ($music == 1) {
		$SIG{INT} = sub { exit(); };
		#system("$musicplayer $musicvolumecmd$musicvolume $musicdir@musicfiles[0] $musictermquiet");
		while ($music == 1) {
			system("$musicplayer $musicvolumecmd$rrmusicvolume $musicdir@rrmusicfiles[(int(rand(@rrmusicfiles)))] $musictermquiet");
		}
	}
}

sub bankplaymusic {
	if ($music == 1) {
		$SIG{INT} = sub { exit(); };
		#system("$musicplayer $musicvolumecmd$musicvolume $musicdir@musicfiles[0] $musictermquiet");
		while ($music == 1) {
			system("$musicplayer $musicvolumecmd$bankmusicvolume $musicdir@bankmusicfiles[(int(rand(@bankmusicfiles)))] $musictermquiet");
		}
	}
}

sub beepalrm {
	#This will always add a newline.
	#If soundfx = 1 and beepnum > 0 then it will print a beep aswell
	#Be sure to set $beepnum to 0 at the end of your printed screen
	if ($soundfx == 1) {
		if ($beepnum > 0) {
			if ($beepnum == 1) {
				print"\a";
				print"\n";
			} else {
				print"\a";
				print"\n";
				if ($compatUNIXY == 1) {
					select undef, undef, undef, 0.15;
				}
			}
			$beepnum = $beepnum - 1;
		} else {
			print"\n";
		}
	} else {
		print"\n";
	}
}

sub medpause {
	if ($compatUNIXY == 1) {
		if ($anispeed == 3) {
			select undef, undef, undef, 1.80;
		} elsif ($anispeed == 2) {
			select undef, undef, undef, 1.20;
		} else {
			select undef, undef, undef, 0.60;
		}
	} else {
		sleep(1);
	}
}

sub smallpause {
	if ($compatUNIXY == 1) {
		if ($anispeed == 3) {
			select undef, undef, undef, 0.90;
		} elsif ($anispeed == 2) {
			select undef, undef, undef, 0.60;
		} else {
			select undef, undef, undef, 0.30;
		}
	} else {
		sleep(1);
	}
}

sub tinypause {
	if ($compatUNIXY == 1) {
		if ($anispeed == 3) {
			select undef, undef, undef, 0.45;
		} elsif ($anispeed == 2) {
			select undef, undef, undef, 0.30;
		} else {
			select undef, undef, undef, 0.15;
		}
	} else {
		sleep(1);
	}
}

sub p7pause {
	if ($compatUNIXY == 1) {
		if ($anispeed == 3) {
			select undef, undef, undef, 0.21;
		} elsif ($anispeed == 2) {
			select undef, undef, undef, 0.14;
		} else {
			select undef, undef, undef, 0.07;
		}
	} else {
		sleep(0);
	}
}

sub p4pause {
	if ($compatUNIXY == 1) {
		if ($anispeed == 3) {
			select undef, undef, undef, 0.12;
		} elsif ($anispeed == 2) {
			select undef, undef, undef, 0.08;
		} else {
			select undef, undef, undef, 0.04;
		}
	} else {
		sleep(0);
	}
}

sub spinreel {
	$slotsymbol1 = int(rand($hrrandnums));
	$slotsymbol2 = int(rand($hrrandnums));
	$slotsymbol3 = int(rand($hrrandnums));
}

#2
sub symseven1  { print colored('  7777777777777777  ',"$red on_$bgcwhite"); }
sub symseven2  { print colored('  7777777777777777  ',"$red on_$bgcwhite"); }
sub symseven3  { print colored('  777       777777  ',"$red on_$bgcwhite"); }
sub symseven4  { print colored('           777777   ',"$red on_$bgcwhite"); }
sub symseven5  { print colored('          777777    ',"$red on_$bgcwhite"); }
sub symseven6  { print colored('         777777     ',"$red on_$bgcwhite"); }
sub symseven7  { print colored('        7777777     ',"$red on_$bgcwhite"); }
sub symseven8  { print colored('       7777777      ',"$red on_$bgcwhite"); }
sub symseven9  { print colored('      77777777      ',"$red on_$bgcwhite"); }
sub symseven10 { print colored('     777777777      ',"$red on_$bgcwhite"); }
sub symseven11 { print colored('     777777777      ',"$red on_$bgcwhite"); }   
sub symseven12 { print colored('     777777777      ',"$red on_$bgcwhite"); } 
sub symseven13 { print colored('      777777777     ',"$red on_$bgcwhite"); }                  
sub symseven14 { print colored('       777777777    ',"$red on_$bgcwhite"); }

#6	
sub symdollar1  { print colored('        $$$$        ',"$green on_$bgcwhite"); } 
sub symdollar2  { print colored('     SSSSSSSSSS     ',"$boldgreen on_$bgcwhite"); } 
sub symdollar3  { print colored('   SSSSSSSSSSSSSS   ',"$boldgreen on_$bgcwhite"); }
sub symdollar4  { print colored('  SSSS',"$boldgreen on_$bgcwhite"); print colored('  $$$$  ',"$green on_$bgcwhite"); print colored('SSSS  ',"$boldgreen on_$bgcwhite"); }
sub symdollar5  { print colored('  SSS',"$boldgreen on_$bgcwhite"); print colored('   $$$$        ',"$green on_$bgcwhite"); }
sub symdollar6  { print colored('  SSSS',"$boldgreen on_$bgcwhite"); print colored('  $$$$        ',"$green on_$bgcwhite"); }
sub symdollar7  { print colored('   SSSSS',"$boldgreen on_$bgcwhite"); print colored('$$$$',"$green on_$bgcwhite"); print colored('SSS     ',"$boldgreen on_$bgcwhite"); }
sub symdollar8  { print colored('     SSS',"$boldgreen on_$bgcwhite"); print colored('$$$$',"$green on_$bgcwhite"); print colored('SSSSS   ',"$boldgreen on_$bgcwhite"); }
sub symdollar9  { print colored('        $$$$',"$green on_$bgcwhite"); print colored('  SSSS  ',"$boldgreen on_$bgcwhite"); }
sub symdollar10 { print colored('        $$$$',"$green on_$bgcwhite"); print colored('   SSS  ',"$boldgreen on_$bgcwhite"); }
sub symdollar11 { print colored('  SSSS',"$boldgreen on_$bgcwhite"); print colored('  $$$$',"$green on_$bgcwhite"); print colored('  SSSS  ',"$boldgreen on_$bgcwhite"); }
sub symdollar12 { print colored('   SSSSSSSSSSSSSS   ',"$boldgreen on_$bgcwhite"); }
sub symdollar13 { print colored('     SSSSSSSSSS     ',"$boldgreen on_$bgcwhite"); }
sub symdollar14 { print colored('        $$$$        ',"$green on_$bgcwhite"); }

sub symdollar1a  { print colored('        $$$$        ',"$yellow on_$bgcwhite"); } 
sub symdollar2a  { print colored('     SSSSSSSSSS     ',"$boldyellow on_$bgcwhite"); } 
sub symdollar3a  { print colored('   SSSSS',"$boldyellow on_$bgcwhite");print colored('S',"$boldyellow on_$bgcwhite"); print colored('SSSSSSSS   ',"$boldyellow on_$bgcwhite"); }
sub symdollar4a  { print colored('  SSSS',"$boldyellow on_$bgcwhite"); print colored('  A$$Y  ',"$yellow on_$bgcwhite"); print colored('SSSS  ',"$boldyellow on_$bgcwhite"); }
sub symdollar5a  { print colored('  SSS',"$boldyellow on_$bgcwhite"); print colored('   L$$T        ',"$yellow on_$bgcwhite"); }
sub symdollar6a  { print colored('  SSSS',"$boldyellow on_$bgcwhite"); print colored('  M$$H        ',"$yellow on_$bgcwhite"); }
sub symdollar7a  { print colored('   SSSSS',"$boldyellow on_$bgcwhite"); print colored('I$$G',"$yellow on_$bgcwhite"); print colored('SSS     ',"$boldyellow on_$bgcwhite"); }
sub symdollar8a  { print colored('     SSS',"$boldyellow on_$bgcwhite"); print colored('G$$I',"$yellow on_$bgcwhite"); print colored('SSSSS   ',"$boldyellow on_$bgcwhite"); }
sub symdollar9a  { print colored('        H$$M',"$yellow on_$bgcwhite"); print colored('  SSSS  ',"$boldyellow on_$bgcwhite"); }
sub symdollar10a { print colored('        T$$L',"$yellow on_$bgcwhite"); print colored('   SSS  ',"$boldyellow on_$bgcwhite"); }
sub symdollar11a { print colored('  SSSS',"$boldyellow on_$bgcwhite"); print colored('  Y$$A',"$yellow on_$bgcwhite"); print colored('  SSSS  ',"$boldyellow on_$bgcwhite"); }
sub symdollar12a { print colored('   SSSSSSSS',"$boldyellow on_$bgcwhite"); print colored('S',"$boldyellow on_$bgcwhite"); print colored('SSSSS   ',"$boldyellow on_$bgcwhite"); }
sub symdollar13a { print colored('     SSSSSSSSSS     ',"$boldyellow on_$bgcwhite"); }
sub symdollar14a { print colored('        $$$$        ',"$yellow on_$bgcwhite"); }

sub symdollar1b  { print colored('        $$$$        ',"$boldblack on_$bgcwhite"); } 
sub symdollar2b  { print colored('     SSSSSSSSSS     ',"$boldwhite on_$bgcwhite"); } 
sub symdollar3b  { print colored('   SSSSSSSSSSSSSS   ',"$boldwhite on_$bgcwhite"); }
sub symdollar4b  { print colored('  SSSS',"$boldwhite on_$bgcwhite"); print colored('  $$$$  ',"$boldblack on_$bgcwhite"); print colored('SSSS  ',"$boldwhite on_$bgcwhite"); }
sub symdollar5b  { print colored('  SSS',"$boldwhite on_$bgcwhite"); print colored('   $$$$        ',"$boldblack on_$bgcwhite"); }
sub symdollar6b  { print colored('  SSSS',"$boldwhite on_$bgcwhite"); print colored('  $$$$        ',"$boldblack on_$bgcwhite"); }
sub symdollar7b  { print colored('   SSSSS',"$boldwhite on_$bgcwhite"); print colored('$$$$',"$boldblack on_$bgcwhite"); print colored('SSS     ',"$boldwhite on_$bgcwhite"); }
sub symdollar8b  { print colored('     SSS',"$boldwhite on_$bgcwhite"); print colored('$$$$',"$boldblack on_$bgcwhite"); print colored('SSSSS   ',"$boldwhite on_$bgcwhite"); }
sub symdollar9b  { print colored('        $$$$',"$boldblack on_$bgcwhite"); print colored('  SSSS  ',"$boldwhite on_$bgcwhite"); }
sub symdollar10b { print colored('        $$$$',"$boldblack on_$bgcwhite"); print colored('   SSS  ',"$boldwhite on_$bgcwhite"); }
sub symdollar11b { print colored('  SSSS',"$boldwhite on_$bgcwhite"); print colored('  $$$$',"$boldblack on_$bgcwhite"); print colored('  SSSS  ',"$boldwhite on_$bgcwhite"); }
sub symdollar12b { print colored('   SSSSSSSSSSSSSS   ',"$boldwhite on_$bgcwhite"); }
sub symdollar13b { print colored('     SSSSSSSSSS     ',"$boldwhite on_$bgcwhite"); }
sub symdollar14b { print colored('        $$$$        ',"$boldblack on_$bgcwhite"); }

sub symbar0  { print colored(' ',"$green on_$bgcwhite"); print colored('                 ',"$boldwhite on_$bgcblack"); print colored('  ',"$green on_$bgcwhite"); }

#5
sub symbar1  { print colored(' ',"$green on_$bgcwhite"); print colored('    B   A   R    ',"$cyan on_$bgcblack"); print colored('  ',"$green on_$bgcwhite"); }

#4
sub symbar2  { print colored(' ',"$green on_$bgcwhite"); print colored('    B   A   R    ',"$boldmagenta on_$bgcblack"); print colored('  ',"$green on_$bgcwhite"); }

#3
sub symbar3  { print colored(' ',"$green on_$bgcwhite"); print colored('    B   A   R    ',"$boldyellow on_$bgcblack"); print colored('  ',"$green on_$bgcwhite"); }


#1
sub symgnu5  { print colored(' ',"$green on_$bgcwhite"); print colored('* * * * * * * * *',"$boldwhite on_$bgcwhite"); print colored('  ',"$green on_$bgcwhite"); }
sub symgnu6  { print colored(' ',"$green on_$bgcwhite"); print colored(' * * * * * * * * ',"$boldblue on_$bgcblue"); print colored('  ',"$green on_$bgcwhite"); }
sub symgnu7  { print colored(' ',"$green on_$bgcwhite"); print colored('* * * G N U * * *',"$boldblue on_$bgcwhite"); print colored('  ',"$green on_$bgcwhite"); }
sub symgnu8  { print colored(' ',"$green on_$bgcwhite"); print colored(' * * * * * * * * ',"$boldblue on_$bgcblue"); print colored('  ',"$green on_$bgcwhite"); }
sub symgnu9  { print colored(' ',"$green on_$bgcwhite"); print colored('* * * * * * * * *',"$boldwhite on_$bgcwhite"); print colored('  ',"$green on_$bgcwhite"); }

#10
sub symcherry2  { print colored('           xX       ',"$boldgreen on_$bgcwhite"); }
sub symcherry3  { print colored('          xX        ',"$boldgreen on_$bgcwhite"); }
sub symcherry4  { print colored('         xXXx       ',"$boldgreen on_$bgcwhite"); }
sub symcherry5  { print colored('        xX  Xx      ',"$boldgreen on_$bgcwhite"); }
sub symcherry6  { print colored('       xX    Xx     ',"$boldgreen on_$bgcwhite"); }
sub symcherry7  { print colored('      xX',"$boldgreen on_$bgcwhite"); print colored('   CCCCCC   ',"$boldred on_$bgcwhite"); }
sub symcherry8  { print colored('     xX',"$boldgreen on_$bgcwhite"); print colored('   CCCCCCCC  ',"$boldred on_$bgcwhite"); }
sub symcherry9  { print colored('  CCCCCC  CCCCCCC',"$boldred on_$bgcwhite"); print colored('C  ',"$red on_$bgcwhite"); }
sub symcherry10 { print colored(' CCCCCCCC CCCCCC',"$boldred on_$bgcwhite"); print colored('CC  ',"$red on_$bgcwhite"); }
sub symcherry11 { print colored(' CCCCCCC',"$boldred on_$bgcwhite"); print colored('C  CCCCCC   ',"$red on_$bgcwhite"); }
sub symcherry12 { print colored(' CCCCC',"$boldred on_$bgcwhite"); print colored('CCC           ',"$red on_$bgcwhite"); }
sub symcherry13 { print colored('  CCCCCC            ',"$red on_$bgcwhite"); }

#b
sub symbonus3  { print colored('         0          ',"$magenta on_$bgcwhite"); }
sub symbonus4  { print colored('        000         ',"$boldmagenta on_$bgcwhite"); }
sub symbonus5  { print colored('    [BONUSBONU]     ',"$red on_$bgcwhite"); }
sub symbonus6  { print colored('    [SBONUSBON]     ',"$boldred on_$bgcwhite"); }
sub symbonus7  { 
print colored('  ',"$magenta on_$bgcwhite");
print colored('  ',"$magenta on_$bgcblue");
print colored(' B',"$boldyellow on_$bgcmagenta");
print colored('  ',"$magenta on_$bgcblue");
print colored(' N',"$boldyellow on_$bgcmagenta");
print colored('  ',"$magenta on_$bgcblue");
print colored(' S',"$boldyellow on_$bgcmagenta");
print colored('  ',"$magenta on_$bgcblue");
print colored('  ',"$blue on_$bgcmagenta");
print colored('  ',"$magenta on_$bgcwhite");
}
sub symbonus8  { 
print colored('  ',"$magenta on_$bgcwhite");
print colored('  ',"$blue on_$bgcmagenta");
print colored('  ',"$magenta on_$bgcblue");
print colored(' O',"$boldyellow on_$bgcmagenta");
print colored('  ',"$magenta on_$bgcblue");
print colored(' U',"$boldyellow on_$bgcmagenta");
print colored('  ',"$magenta on_$bgcblue");
print colored('  ',"$blue on_$bgcmagenta");
print colored('  ',"$magenta on_$bgcblue");
print colored('  ',"$magenta on_$bgcwhite");
}
sub symbonus9  { print colored('    \uSBONUSBo/     ',"$red on_$bgcwhite"); }
sub symbonus10  { 
print colored('  ',"$magenta on_$bgcwhite");
print colored('  ',"$magenta on_$bgcblue");
print colored('  ',"$blue on_$bgcmagenta");
print colored('  ',"$boldyellow on_$bgcblue");
print colored('O ',"$boldyellow on_$bgcmagenta");
print colored('  ',"$boldyellow on_$bgcblue");
print colored('U ',"$boldyellow on_$bgcmagenta");
print colored('  ',"$magenta on_$bgcblue");
print colored('  ',"$blue on_$bgcmagenta");
print colored('  ',"$magenta on_$bgcwhite");
}
sub symbonus11  { 
print colored('  ',"$magenta on_$bgcwhite");
print colored('  ',"$blue on_$bgcmagenta");
print colored('  ',"$boldyellow on_$bgcblue");
print colored('B ',"$boldyellow on_$bgcmagenta");
print colored('  ',"$boldyellow on_$bgcblue");
print colored('N ',"$boldyellow on_$bgcmagenta");
print colored('  ',"$boldyellow on_$bgcblue");
print colored('S ',"$boldyellow on_$bgcmagenta");
print colored('  ',"$magenta on_$bgcblue");
print colored('  ',"$magenta on_$bgcwhite");
}
sub symbonus12 { print colored('       \nUs/        ',"$boldred on_$bgcwhite"); }
sub symbonus13 { print colored('        \b/         ',"$red on_$bgcwhite"); }

#9
sub symbell3  { print colored('         x          ',"$boldyellow on_$bgcwhite"); }
sub symbell4  { print colored('        xXx         ',"$boldyellow on_$bgcwhite"); }
sub symbell5  { print colored('       xXXXx        ',"$boldyellow on_$bgcwhite"); }
sub symbell6  { print colored('      xXXXXXx       ',"$boldyellow on_$bgcwhite"); }
sub symbell7  { print colored('     xXXXXXXXx      ',"$boldyellow on_$bgcwhite"); }
sub symbell8  { print colored('     XXXXXXXXX      ',"$boldyellow on_$bgcwhite"); }
sub symbell9  { print colored('     XXXXXXXXX      ',"$boldyellow on_$bgcwhite"); }
sub symbell10 { print colored('     XXXXXXXXX      ',"$boldyellow on_$bgcwhite"); }
sub symbell11 { print colored('     XXXXXXXXX      ',"$boldyellow on_$bgcwhite"); }
sub symbell12 { print colored('        000         ',"$yellow on_$bgcwhite"); }
sub symbell13 { print colored('         0          ',"$yellow on_$bgcwhite"); }

#8
sub symolive1  { print colored('       00000        ',"$boldmagenta on_$bgcwhite"); }
sub symolive2  { print colored('    0000',"$boldmagenta on_$bgcwhite"); print colored('0000000     ',"$magenta on_$bgcwhite"); }
sub symolive3  { print colored('  000',"$boldmagenta on_$bgcwhite"); print colored('000000',"$magenta on_$bgcwhite"); print colored('000',"$green on_$bgcwhite"); print colored('000   ',"$magenta on_$bgcwhite"); }
sub symolive4  { print colored(' 00',"$boldmagenta on_$bgcwhite"); print colored('0000000',"$magenta on_$bgcwhite"); print colored('00',"$green on_$bgcwhite"); print colored('0',"$yellow on_$bgcwhite"); print colored('00',"$green on_$bgcwhite"); print colored('000  ',"$magenta on_$bgcwhite"); }
sub symolive5  { print colored('00',"$boldmagenta on_$bgcwhite"); print colored('000000000',"$magenta on_$bgcwhite"); print colored('000',"$green on_$bgcwhite"); print colored('00000 ',"$magenta on_$bgcwhite"); }
sub symolive6  { print colored('0',"$boldmagenta on_$bgcwhite"); print colored('000000000000000000 ',"$magenta on_$bgcwhite"); }
sub symolive7  { print colored('0000000000000000000 ',"$magenta on_$bgcwhite"); }
sub symolive8  { print colored('0000000000000000000 ',"$magenta on_$bgcwhite"); }
sub symolive9  { print colored('0000000000000000000 ',"$magenta on_$bgcwhite"); }
sub symolive10 { print colored('0000000000000000000 ',"$magenta on_$bgcwhite"); }
sub symolive11 { print colored(' 00000000000000000  ',"$magenta on_$bgcwhite"); }
sub symolive12 { print colored('  000000000000000   ',"$magenta on_$bgcwhite"); }
sub symolive13 { print colored('    00000000000     ',"$magenta on_$bgcwhite"); }
sub symolive14 { print colored('       00000        ',"$magenta on_$bgcwhite"); }

#7
sub symstar3   { if ($reel == 1) { $starcolor = "$boldred"; } elsif ($reel == 2) { $starcolor = "$boldwhite"; } else { $starcolor = "$boldblue"; } print colored('         *          ',"$starcolor on_$bgcwhite"); }
sub symstar4   { if ($reel == 1) { $starcolor = "$red"; } elsif ($reel == 2) { $starcolor = "$boldblack"; } else { $starcolor = "$blue"; } print colored('        ***         ',"$starcolor on_$bgcwhite"); }
sub symstar5   { if ($reel == 1) { $starcolor = "$boldred"; } elsif ($reel == 2) { $starcolor = "$boldwhite"; } else { $starcolor = "$boldblue"; } print colored('       *****        ',"$starcolor on_$bgcwhite"); }
sub symstar6   { if ($reel == 1) { $starcolor = "$red"; } elsif ($reel == 2) { $starcolor = "$boldblack"; } else { $starcolor = "$blue"; } print colored(' ****************** ',"$starcolor on_$bgcwhite"); }
sub symstar7   { if ($reel == 1) { $starcolor = "$boldred"; } elsif ($reel == 2) { $starcolor = "$boldwhite"; } else { $starcolor = "$boldblue"; } print colored('   **************   ',"$starcolor on_$bgcwhite"); }
sub symstar8   { if ($reel == 1) { $starcolor = "$red"; } elsif ($reel == 2) { $starcolor = "$boldblack"; } else { $starcolor = "$blue"; } print colored('     **********     ',"$starcolor on_$bgcwhite"); }
sub symstar9   { if ($reel == 1) { $starcolor = "$boldred"; } elsif ($reel == 2) { $starcolor = "$boldwhite"; } else { $starcolor = "$boldblue"; } print colored('     **********     ',"$starcolor on_$bgcwhite"); }
sub symstar10  { if ($reel == 1) { $starcolor = "$red"; } elsif ($reel == 2) { $starcolor = "$boldblack"; } else { $starcolor = "$blue"; } print colored('    *****  *****    ',"$starcolor on_$bgcwhite"); }
sub symstar11  { if ($reel == 1) { $starcolor = "$boldred"; } elsif ($reel == 2) { $starcolor = "$boldwhite"; } else { $starcolor = "$boldblue"; } print colored('   ****      ****   ',"$starcolor on_$bgcwhite"); }
sub symstar12  { if ($reel == 1) { $starcolor = "$red"; } elsif ($reel == 2) { $starcolor = "$boldblack"; } else { $starcolor = "$blue"; } print colored('  **            **  ',"$starcolor on_$bgcwhite"); }

sub symwhite   { print colored('                    ',"$boldyellow on_$bgcwhite"); }

sub symspining { print colored('||||||||||||||||||||',"$boldwhite on_$bgcwhite"); }

sub slot1 {
	if ($slot1 eq 'spining') {
		symspining();
	} elsif ($slot1 == 2) {
		symseven1();
	} elsif ($slot1 == 6) {
		symdollar1();
	} elsif ($slot1 == 8) {
		symolive1();
	} elsif ($slot1 == 11) {
		symseven10();
	} elsif ($slot1 == 12) {
		symbar0();
	} elsif ($slot1 == 13) {
		symcherry9();
	} elsif ($slot1 == 14) {
		symbell10();
	} elsif ($slot1 == 15) {
		symstar10();
	} elsif ($slot1 == 16) {
		symdollar1a();
	} elsif ($slot1 == 17) {
		symgnu8();
	} elsif ($slot1 == 18) {
		symolive10();
	} elsif ($slot1 == 19) {
		symdollar10();
	} elsif ($slot1 == 21) {
		symdollar1b();								
	} else { 
		symwhite();
	}
}

sub slot2 {
	if ($slot2 eq 'spining') {
		symspining();
	} elsif ($slot2 == 2) {
		symseven2();
	} elsif ($slot2 == 3) {
		symbar0();	
	} elsif ($slot2 == 6) {
		symdollar2();	
	} elsif ($slot2 == 8) {
		symolive2();
	} elsif ($slot2 == 10) {
		symcherry2();
	} elsif ($slot2 == 11) {
		symseven11();
	} elsif ($slot2 == 12) {
		symbar3();
	} elsif ($slot2 == 13) {
		symcherry10();
	} elsif ($slot2 == 14) {
		symbell11();
	} elsif ($slot2 == 15) {
		symstar11();
	} elsif ($slot2 == 16) {
		symdollar2a();
	} elsif ($slot2 == 17) {
		symgnu9();
	} elsif ($slot2 == 18) {
		symolive11();
	} elsif ($slot2 == 19) {
		symdollar11();
	} elsif ($slot2 == 20) {
		symbar0();
	} elsif ($slot2 == 21) {
		symdollar2b();		
	} else { 
		symwhite();
	}
}

sub slot3 {
	if ($slot3 eq 'spining') {
		symspining();
	} elsif ($slot3 == 2) {
		symseven3();
	} elsif ($slot3 == 3) {
		symbar3();
	} elsif ($slot3 == 6) {
		symdollar3();
	} elsif ($slot3 == 7) {
		symstar3();	
	} elsif ($slot3 == 8) {
		symolive3();
	} elsif ($slot3 == 9) {	
		symbell3();
	} elsif ($slot3 eq 'b') {	
		symbonus3();
	} elsif ($slot3 == 10) {
		symcherry3();
	} elsif ($slot3 == 11) {
		symseven12();
	} elsif ($slot3 == 12) {
		symbar0();
	} elsif ($slot3 == 13) {
		symcherry11();
	} elsif ($slot3 == 14) {
		symbell12();
	} elsif ($slot3 == 15) {
		symstar12();
	} elsif ($slot3 == 16) {
		symdollar3a();
	} elsif ($slot3 == 18) {
		symolive12();
	} elsif ($slot3 == 19) {
		symdollar12();
	} elsif ($slot3 == 20) {
		symbar2();
	} elsif ($slot3 == 21) {
		symdollar3b();											
	} else { 
		symwhite();
	}
}

sub slot4 {
	if ($slot4 eq 'spining') {
		symspining();
	} elsif ($slot4 == 2) {
		symseven4();
	} elsif ($slot4 == 3) {
		symbar0();
	} elsif ($slot4 == 4) {
		symbar0();		
	} elsif ($slot4 == 6) {
		symdollar4();
	} elsif ($slot4 == 7) {
		symstar4();	
	} elsif ($slot4 == 8) {
		symolive4();
	} elsif ($slot4 == 9) {	
		symbell4();
	} elsif ($slot4 eq 'b') {	
		symbonus4();
	} elsif ($slot4 == 10) {
		symcherry4();
	} elsif ($slot4 == 11) {
		symseven13();
	} elsif ($slot4 == 13) {
		symcherry12();
	} elsif ($slot4 == 14) {
		symbell13();
	} elsif ($slot4 == 16) {
		symdollar4a();
	} elsif ($slot4 == 18) {
		symolive13();
	} elsif ($slot4 == 19) {
		symdollar13();
	} elsif ($slot4 == 20) {
		symbar0();
	} elsif ($slot4 == 21) {
		symdollar4b();												
	} else { 
		symwhite();
	}
}

sub slot5 {
	if ($slot5 eq 'spining') {
		symspining();
	} elsif ($slot5 == 1) {
		symgnu5();
	} elsif ($slot5 == 2) {
		symseven5();
	} elsif ($slot5 == 4) {
		symbar2();		
	} elsif ($slot5 == 6) {
		symdollar5();
	} elsif ($slot5 == 7) {
		symstar5();	
	} elsif ($slot5 == 8) {
		symolive5();
	} elsif ($slot5 == 9) {	
		symbell5();
	} elsif ($slot5 eq 'b') {	
		symbonus5();
	} elsif ($slot5 == 10) {
		symcherry5();
	} elsif ($slot5 == 11) {
		symseven14();
	} elsif ($slot5 == 13) {
		symcherry13();
	} elsif ($slot5 == 16) {
		symdollar5a();
	} elsif ($slot5 == 18) {
		symolive14();
	} elsif ($slot5 == 19) {
		symdollar14();
	} elsif ($slot5 == 21) {
		symdollar5b();							
	} else { 
		symwhite();
	}
}

sub slot6 {
	if ($slot6 eq 'spining') {
		symspining();
	} elsif ($slot6 == 1) {
		symgnu6();
	} elsif ($slot6 == 2) {
		symseven6();
	} elsif ($slot6 == 3) {
		symbar0();
	} elsif ($slot6 == 4) {
		symbar0();				
	} elsif ($slot6 == 5) {
		symbar0();			
	} elsif ($slot6 == 6) {
		symdollar6();
	} elsif ($slot6 == 7) {
		symstar6();	
	} elsif ($slot6 == 8) {
		symolive6();
	} elsif ($slot6 == 9) {	
		symbell6();
	} elsif ($slot6 eq 'b') {	
		symbonus6();
	} elsif ($slot6 == 10) {
		symcherry6();
	} elsif ($slot6 == 16) {
		symdollar6a();
	} elsif ($slot6 == 21) {
		symdollar6b();					
	} else { 
		symwhite();
	}
}
		
sub slot7 {	
	if ($slot7 eq 'spining') {
		symspining();
	} elsif ($slot7 == 1) {
		symgnu7();
	} elsif ($slot7 == 2) {
		symseven7();
	} elsif ($slot7 == 3) {
		symbar3();
	} elsif ($slot7 == 5) {
		symbar1();		
	} elsif ($slot7 == 6) {
		symdollar7();
	} elsif ($slot7 == 7) {
		symstar7();	
	} elsif ($slot7 == 8) {
		symolive7();
	} elsif ($slot7 == 9) {	
		symbell7();
	} elsif ($slot7 eq 'b') {	
		symbonus7();
	} elsif ($slot7 == 10) {
		symcherry7();
	} elsif ($slot7 == 16) {
		symdollar7a();
	} elsif ($slot7 == 21) {
		symdollar7b();			
	} else { 
		symwhite();
	}
}

sub slot8 {
	if ($slot8 eq 'spining') {
		symspining();
	} elsif ($slot8 == 1) {
		symgnu8();
	} elsif ($slot8 == 2) {
		symseven8();
	} elsif ($slot8 == 3) {
		symbar0();
	} elsif ($slot8 == 4) {
		symbar0();		
	} elsif ($slot8 == 5) {
		symbar0();		
	} elsif ($slot8 == 6) {
		symdollar8();
	} elsif ($slot8 == 7) {
		symstar8();	
	} elsif ($slot8 == 8) {
		symolive8();
	} elsif ($slot8 == 9) {	
		symbell8();
	} elsif ($slot8 eq 'b') {	
		symbonus8();
	} elsif ($slot8 == 10) {
		symcherry8();
	} elsif ($slot8 == 16) {
		symdollar8a();
	} elsif ($slot8 == 21) {
		symdollar8b();			
	} else { 
		symwhite();
	}
}

sub slot9 {
	if ($slot9 eq 'spining') {
		symspining();
	} elsif ($slot9 == 1) {
		symgnu9();
	} elsif ($slot9 == 2) {
		symseven9();
	} elsif ($slot8 == 4) {
		symbar2();		
	} elsif ($slot9 == 6) {
		symdollar9();
	} elsif ($slot9 == 7) {
		symstar9();	
	} elsif ($slot9 == 8) {
		symolive9();
	} elsif ($slot9 == 9) {	
		symbell9();
	} elsif ($slot9 eq 'b') {	
		symbonus9();
	} elsif ($slot9 == 10) {
		symcherry9();
	} elsif ($slot9 == 16) {
		symdollar9a();
	} elsif ($slot9 == 21) {
		symdollar9b();			
	} else { 
		symwhite();
	}
}

sub slot10 {
	if ($slot10 eq 'spining') {
		symspining();
	} elsif ($slot10 == 2) {
		symseven10();
	} elsif ($slot10 == 3) {
		symbar0();
	} elsif ($slot10 == 4) {
		symbar0();		
	} elsif ($slot10 == 6) {
		symdollar10();
	} elsif ($slot10 == 7) {
		symstar10();	
	} elsif ($slot10 == 8) {
		symolive10();
	} elsif ($slot10 == 9) {	
		symbell10();
	} elsif ($slot10 eq 'b') {	
		symbonus10();
	} elsif ($slot10 == 10) {
		symcherry10();
	} elsif ($slot10 == 11) {
		symdollar1();
	} elsif ($slot10 == 15) {
		symolive1();
	} elsif ($slot10 == 16) {
		symdollar10a();
	} elsif ($slot10 == 18) {
		symseven1();
	} elsif ($slot10 == 21) {
		symdollar10b();
	} else { 
		symwhite();
	}
}

sub slot11 {
	if ($slot11 eq 'spining') {
		symspining();
	} elsif ($slot11 == 2) {
		symseven11();
	} elsif ($slot11 == 3) {
		symbar3();
	} elsif ($slot11 == 6) {
		symdollar11();
	} elsif ($slot11 == 7) {
		symstar11();	
	} elsif ($slot11 == 8) {
		symolive11();
	} elsif ($slot11 == 9) {	
		symbell11();
	} elsif ($slot11 eq 'b') {	
		symbonus11();
	} elsif ($slot11 == 10) {
		symcherry11();
	} elsif ($slot11 == 11) {
		symdollar2();
	} elsif ($slot11 == 15) {
		symolive2();
	} elsif ($slot11 == 16) {
		symdollar11a();
	} elsif ($slot11 == 18) {
		symseven2();
	} elsif ($slot11 == 19) {
		symcherry2();
	} elsif ($slot11 == 21) {
		symdollar11b();
	} else { 
		symwhite();
	}
}

sub slot12 {
	if ($slot12 eq 'spining') {
		symspining();
	} elsif ($slot12 == 2) {
		symseven12();
	} elsif ($slot12 == 3) {
		symbar0();
	} elsif ($slot12 == 6) {
		symdollar12();
	} elsif ($slot12 == 7) {
		symstar12();	
	} elsif ($slot12 == 8) {
		symolive12();
	} elsif ($slot12 == 9) {	
		symbell12();
	} elsif ($slot12 eq 'b') {	
		symbonus12();
	} elsif ($slot12 == 10) {
		symcherry12();
	} elsif ($slot12 == 11) {
		symdollar3();
	} elsif ($slot12 == 12) {
		symstar3();
	} elsif ($slot12 == 12) {
		symbell3();
	} elsif ($slot12 == 13) {
		symbell3();
	} elsif ($slot12 == 15) {
		symolive3();
	} elsif ($slot12 == 16) {
		symdollar12a();
	} elsif ($slot12 == 17) {
		symdollar1();
	} elsif ($slot12 == 18) {
		symseven3();
	} elsif ($slot12 == 19) {
		symcherry3();
	} elsif ($slot12 == 21) {
		symdollar12b();
	} else { 
		symwhite();
	}
}

sub slot13 {
	if ($slot13 eq 'spining') {
		symspining();
	} elsif ($slot13 == 2) {
		symseven13();
	} elsif ($slot13 == 6) {
		symdollar13();	
	} elsif ($slot13 == 8) {
		symolive13();
	} elsif ($slot13 == 9) {	
		symbell13();
	} elsif ($slot13 eq 'b') {	
		symbonus13();
	} elsif ($slot13 == 10) {
		symcherry13();
	} elsif ($slot13 == 11) {
		symdollar4();
	} elsif ($slot13 == 12) {
		symstar4();
	} elsif ($slot13 == 13) {
		symbell4();
	} elsif ($slot13 == 14) {
		symbar0();
	} elsif ($slot13 == 15) {	
		symolive4();
	} elsif ($slot13 == 16) {
		symdollar13a();
	} elsif ($slot13 == 17) {
		symdollar2();
	} elsif ($slot13 == 18) {
		symseven4();
	} elsif ($slot13 == 19) {
		symcherry4();
	} elsif ($slot13 == 20) {
		symbar0();
	} elsif ($slot13 == 21) {
		symdollar13b();						
	} else { 
		symwhite();
	}
}

sub slot14 {
	if ($slot14 eq 'spining') {
		symspining();
	} elsif ($slot14 == 2) {
		symseven14();
	} elsif ($slot14 == 6) {
		symdollar14();	
	} elsif ($slot14 == 8) {
		symolive14();
	} elsif ($slot14 == 11) {
		symdollar5();
	} elsif ($slot14 == 12) {
		symstar5();
	} elsif ($slot14 == 13) {
		symbell5();
	} elsif ($slot14 == 14) {
		symbar2();
	} elsif ($slot14 == 15) {	
		symolive5();
	} elsif ($slot14 == 16) {
		symdollar14a();
	} elsif ($slot14 == 17) {
		symdollar3();
	} elsif ($slot14 == 18) {
		symseven5();
	} elsif ($slot14 == 19) {
		symcherry5();
	} elsif ($slot14 == 20) {
		symbar3();
	} elsif ($slot14 == 21) {
		symdollar14b();									
	} else { 
		symwhite();
	}
}

sub reeltrans {

	if ($slotsymbol1 <= 18) {
		if ($hrbonus > 0) {
		#Change the cherry into a bell if bonus round is running
		$svslot1 = 9;
		} else {
		$svslot1 = 10;
		$anycherry1 = 1;
		$onecherry = 1;
		}
	} elsif ($slotsymbol1 <= 34) {
		$svslot1 = 9;
	} elsif ($slotsymbol1 <= 48) {
		$svslot1 = 8;
	} elsif ($slotsymbol1 <= 60) {
		$svslot1 = 7;
	} elsif ($slotsymbol1 <= 69) {
		$svslot1 = 6;
		$anydollar1 = 1;
	} elsif ($slotsymbol1 == 70) {
		$svslot1 = 21;
		$anydollar1 = 1;
	} elsif ($slotsymbol1 <= 78) {
		$svslot1 = 5;	
		$anybar1 = 1;
	} elsif ($slotsymbol1 <= 84) {
		$svslot1 = 4;
		$anybar1 = 1;
	} elsif ($slotsymbol1 <= 88) {
		$svslot1 = 3;
		$anybar1 = 1;
	} elsif ($slotsymbol1 <= 90) {
		$svslot1 = 2;	
	} elsif ($slotsymbol1 <= 91) {
		$svslot1 = 1;
	} elsif ($slotsymbol1 <= 92) {
		if ($hrbonus > 0) {
		#Change the misalign into a bell if bonus round is running
		$svslot1 = 9;
		} else {
		$svslot1 = 11;
		$nonep = 1;
		}
	} elsif ($slotsymbol1 <= 93) {
		if ($hrbonus > 0) {
		#Change the misalign into a bell if bonus round is running
		$svslot1 = 9;
		} else {
		$svslot1 = 12;
		$nonep = 1;
		}
	} elsif ($slotsymbol1 <= 94) {
		if ($hrbonus > 0) {
		#Change the misalign into a bell if bonus round is running
		$svslot1 = 9;
		} else {
		$svslot1 = 13;
		$nonep = 1;
		}
	} elsif ($slotsymbol1 <= 95) {
		if ($hrbonus > 0) {
		#Change the misalign into a bell if bonus round is running
		$svslot1 = 9;
		} else {
		$svslot1 = 14;
		$nonep = 1;
		}
	} elsif ($slotsymbol1 <= 96) {
		if ($hrbonus > 0) {
		#Change the misalign into a bell if bonus round is running
		$svslot1 = 9;
		} else {
		$svslot1 = 15;
		$nonep = 1;
		}
	} elsif ($slotsymbol1 <= 97) {
		if ($hrbonus > 0) {
		#Change the misalign into a bell if bonus round is running
		$svslot1 = 9;
		} else {
		$svslot1 = 17;
		$nonep = 1;
		}
	} elsif ($slotsymbol1 <= 98) {
		if ($hrbonus > 0) {
		#Change the misalign into a bell if bonus round is running
		$svslot1 = 9;
		} else {
		$svslot1 = 18;
		$nonep = 1;
		}
	} elsif ($slotsymbol1 <= 100) {
		if ($hrbonus > 0) {
		#Change the misalign into a bell if bonus round is running
		$svslot1 = 9;
		} else {
		$svslot1 = 19;
		$nonep = 1;
		}
	} elsif ($slotsymbol1 <= 102) {
		if ($hrbonus > 0) {
		#Change the misalign into a bell if bonus round is running
		$svslot1 = 9;
		} else {
		$svslot1 = 20;
		$nonep = 1;
		}
	} elsif ($slotsymbol1 <= 109) {
		#bonus
		$svslot1 = 'b';						
	} else {
		$svslot1 = 0;
	}
	
	if ($slotsymbol2 <= 18) {
		if ($hrbonus > 0) {
		#Change the cherry into a bell if bonus round is running
		$svslot2 = 9;
		} else {
		$svslot2 = 10;
		$anycherry2 = 1;
		}
	} elsif ($slotsymbol2 <= 34) {
		$svslot2 = 9;
	} elsif ($slotsymbol2 <= 48) {
		$svslot2 = 8;
	} elsif ($slotsymbol2 <= 60) {
		$svslot2 = 7;
	} elsif ($slotsymbol2 <= 69) {
		$svslot2 = 6;
		$anydollar2 = 1;
	} elsif ($slotsymbol2 == 70) {
		$svslot2 = 16;	
		$anydollar2 = 1;
	} elsif ($slotsymbol2 <= 78) {
		$svslot2 = 5;
		$anybar2 = 1;	
	} elsif ($slotsymbol2 <= 84) {
		$svslot2 = 4;
		$anybar2 = 1;
	} elsif ($slotsymbol2 <= 88) {
		$svslot2 = 3;
		$anybar2 = 1;
	} elsif ($slotsymbol2 <= 90) {
		$svslot2 = 2;	
	} elsif ($slotsymbol2 <= 91) {
		$svslot2 = 1;
	} elsif ($slotsymbol2 <= 92) {
		if ($hrbonus > 0) {
		#Change the misalign into a bell if bonus round is running
		$svslot2 = 9;
		} else {
		$svslot2 = 11;
		$nonep = 1;
		}
	} elsif ($slotsymbol2 <= 93) {
		if ($hrbonus > 0) {
		#Change the misalign into a bell if bonus round is running
		$svslot2 = 9;
		} else {
		$svslot2 = 12;
		$nonep = 1;
		}
	} elsif ($slotsymbol2 <= 94) {
		if ($hrbonus > 0) {
		#Change the misalign into a bell if bonus round is running
		$svslot2 = 9;
		} else {
		$svslot2 = 13;
		$nonep = 1;
		}
	} elsif ($slotsymbol2 <= 95) {
		if ($hrbonus > 0) {
		#Change the misalign into a bell if bonus round is running
		$svslot2 = 9;
		} else {
		$svslot2 = 14;
		$nonep = 1;
		}
	} elsif ($slotsymbol2 <= 96) {
		if ($hrbonus > 0) {
		#Change the misalign into a bell if bonus round is running
		$svslot2 = 9;
		} else {
		$svslot2 = 15;
		$nonep = 1;
		}
	} elsif ($slotsymbol2 <= 97) {
		if ($hrbonus > 0) {
		#Change the misalign into a bell if bonus round is running
		$svslot2 = 9;
		} else {
		$svslot2 = 17;
		$nonep = 1;
		}
	} elsif ($slotsymbol2 <= 98) {
		if ($hrbonus > 0) {
		#Change the misalign into a bell if bonus round is running
		$svslot2 = 9;
		} else {
		$svslot2 = 18;
		$nonep = 1;
		}
	} elsif ($slotsymbol2 <= 100) {
		if ($hrbonus > 0) {
		#Change the misalign into a bell if bonus round is running
		$svslot2 = 9;
		} else {
		$svslot2 = 19;
		$nonep = 1;
		}
	} elsif ($slotsymbol2 <= 102) {
		if ($hrbonus > 0) {
		#Change the misalign into a bell if bonus round is running
		$svslot2 = 9;
		} else {
		$svslot2 = 20;
		$nonep = 1;
		}
	} elsif ($slotsymbol2 <= 109) {
		#bonus
		$svslot2 = 'b';									
	} else {
		$svslot2 = 0;
	}					
	
	if ($slotsymbol3 <= 18) {
		if ($hrbonus > 0) {
		#Change the cherry into a bell if bonus round is running
		$svslot3 = 9;
		} else {
		$svslot3 = 10;
		$anycherry3 = 1;
		}
	} elsif ($slotsymbol3 <= 34) {
		$svslot3 = 9;
	} elsif ($slotsymbol3 <= 48) {
		$svslot3 = 8;
	} elsif ($slotsymbol3 <= 60) {
		$svslot3 = 7;
	} elsif ($slotsymbol3 <= 69) {
		$svslot3 = 6;
		$anydollar3 = 1;
	} elsif ($slotsymbol3 == 70) {
		$svslot3 = 21;
		$anydollar3 = 1;		
	} elsif ($slotsymbol3 <= 78) {
		$svslot3 = 5;
		$anybar3 = 1;	
	} elsif ($slotsymbol3 <= 84) {
		$svslot3 = 4;
		$anybar3 = 1;
	} elsif ($slotsymbol3 <= 88) {
		$svslot3 = 3;
		$anybar3 = 1;
	} elsif ($slotsymbol3 <= 90) {
		$svslot3 = 2;	
	} elsif ($slotsymbol3 <= 91) {
		$svslot3 = 1;
	} elsif ($slotsymbol3 <= 92) {
		if ($hrbonus > 0) {
		#Change the misalign into a bell if bonus round is running
		$svslot3 = 9;
		} else {
		$svslot3 = 11;
		$nonep = 1;
		}
	} elsif ($slotsymbol3 <= 93) {
		if ($hrbonus > 0) {
		#Change the misalign into a bell if bonus round is running
		$svslot3 = 9;
		} else {
		$svslot3 = 12;
		$nonep = 1;
		}
	} elsif ($slotsymbol3 <= 94) {
		if ($hrbonus > 0) {
		#Change the misalign into a bell if bonus round is running
		$svslot3 = 9;
		} else {
		$svslot3 = 13;
		$nonep = 1;
		}
	} elsif ($slotsymbol3 <= 95) {
		if ($hrbonus > 0) {
		#Change the misalign into a bell if bonus round is running
		$svslot3 = 9;
		} else {
		$svslot3 = 14;
		$nonep = 1;
		}
	} elsif ($slotsymbol3 <= 96) {
		if ($hrbonus > 0) {
		#Change the misalign into a bell if bonus round is running
		$svslot3 = 9;
		} else {
		$svslot3 = 15;
		$nonep = 1;
		}
	} elsif ($slotsymbol3 <= 97) {
		if ($hrbonus > 0) {
		#Change the misalign into a bell if bonus round is running
		$svslot3 = 9;
		} else {
		$svslot3 = 17;
		$nonep = 1;
		}
	} elsif ($slotsymbol3 <= 98) {
		if ($hrbonus > 0) {
		#Change the misalign into a bell if bonus round is running
		$svslot3 = 9;
		} else {
		$svslot3 = 18;
		$nonep = 1;
		}
	} elsif ($slotsymbol3 <= 100) {
		if ($hrbonus > 0) {
		#Change the misalign into a bell if bonus round is running
		$svslot3 = 9;
		} else {
		$svslot3 = 19;
		$nonep = 1;
		}
	} elsif ($slotsymbol3 <= 102) {
		if ($hrbonus > 0) {
		#Change the misalign into a bell if bonus round is running
		$svslot3 = 9;
		} else {
		$svslot3 = 20;
		$nonep = 1;
		}
	} elsif ($slotsymbol3 <= 109) {
		#bonus
		$svslot3 = 'b';							
	} else {
		$svslot3 = 0;
	}	

	$anydollar = $anydollar1 + $anydollar2 + $anydollar3;
	$anydollar1 = 0;
	$anydollar2 = 0;
	$anydollar3 = 0;

	$anybar = $anybar1 + $anybar2 + $anybar3;
	$anybar1 = 0;
	$anybar2 = 0;
	$anybar3 = 0;

	$anycherry = $anycherry1 + $anycherry2;
	$anycherry1 = 0;
	$anycherry2 = 0;

}

sub addmoney {

	if ($x eq "111") {
		$addmoney = 10000 * $coin;
		$beepnum = 8;
		$hrstwin = $hrstwin + 1;
		$hrbulbcolor = "$boldcyan";
	} elsif ($x eq "222") {
		$addmoney = 2000 * $coin;
		$beepnum = 7;
		$hrstwin = $hrstwin + 1;
		$hrbulbcolor = "$red";
	} elsif ($x eq "333") {
		$addmoney = 1000 * $coin;
		$beepnum = 6;
		$hrstwin = $hrstwin + 1;
		$hrbulbcolor = "$white";
	} elsif ($x eq "334") {
		$addmoney = 600 * $coin;
		$beepnum = 6;
		$hrstwin = $hrstwin + 1;
	} elsif ($x eq "335") {
		$addmoney = 450 * $coin;
		$beepnum = 5;
		$hrstwin = $hrstwin + 1;
	} elsif ($x eq "444") {
		$addmoney = 300 * $coin;
		$beepnum = 5;
		$hrstwin = $hrstwin + 1;
		$hrbulbcolor = "$white";
	} elsif ($x eq "445") {
		$addmoney = 200 * $coin;
		$beepnum = 4;
		$hrstwin = $hrstwin + 1;
	} elsif ($x eq "555") {
		$addmoney = 150 * $coin;
		$beepnum = 4;
		$hrstwin = $hrstwin + 1;
		$hrbulbcolor = "$white";
	} elsif ($x eq "556") {
		$addmoney = 20 * $coin;
		$beepnum = 2;
		$hrstwin = $hrstwin + 1;
	} elsif ($x eq "557") {
		$addmoney = 18 * $coin;
		$beepnum = 2;
		$hrstwin = $hrstwin + 1;	
	} elsif ($x eq "558") {
		$addmoney = 16 * $coin;
		$beepnum = 2;
		$hrstwin = $hrstwin + 1;
	} elsif ($x eq "559") {
		$addmoney = 14 * $coin;
		$beepnum = 2;
		$hrstwin = $hrstwin + 1;
	} elsif ($x eq "5510") {
		$addmoney = 12 * $coin;
		$beepnum = 2;
		$hrstwin = $hrstwin + 1;
	} elsif ($x eq "5516") {
		$addmoney = 20 * $coin;
		$beepnum = 2;
		$hrstwin = $hrstwin + 1;
	} elsif ($x eq "5521") {
		$addmoney = 20 * $coin;
		$beepnum = 2;	
		$hrstwin = $hrstwin + 1;
	} elsif ($x eq "666") {
		$addmoney = 80 * $coin;
		$beepnum = 3;
		$hrstwin = $hrstwin + 1;
		$hrbulbcolor = "$white";
	} elsif ($x eq "777") {
		$addmoney = 62 * $coin;
		$beepnum = 3;
		$hrstwin = $hrstwin + 1;
		$hrbulbcolor = "$white";
	} elsif ($x eq "888") {
		$addmoney = 40 * $coin;
		$beepnum = 3;
		$hrstwin = $hrstwin + 1;
		$hrbulbcolor = "$white";
	} elsif ($x eq "999") {
		$addmoney = 25 * $coin;
		$beepnum = 3;
		$hrstwin = $hrstwin + 1;
		$hrbulbcolor = "$white";
		if (($hrrandnums > 103) and ($hrbonus == 0)) {
			#Only set if bonus is allowed and a bonus round isn't on
			$hrbonushlp = $hrbonushlpstd;
			$hrrandnums = 110;
		}
	} elsif ($x eq "101010") {
		$addmoney = 10 * $coin;
		$beepnum = 2;
		$hrstwin = $hrstwin + 1;
		$hrbulbcolor = "$white";
	} elsif ($x eq "bbb") {
		$addmoney = 15 * $coin;
		$beepnum = 4;
		$hrstwin = $hrstwin + 1;	
		$hrbonus = $hrbonus + $hrbonusstd;
	} elsif ($anybar == 3) {
		$addmoney = 22 * $coin;
		$beepnum = 2;
		$hrstwin = $hrstwin + 1;										
	} elsif ($onecherry == 1) {
		if ($nonep >= 1) {
			#nothing
			$beepnum = 0;
			$hrstlose = $hrstlose + 1;
		} else {
			if ($anycherry == 2) {
				if ($anycherry3 >= 1) {
					#nothing
					$beepnum = 0;
					$hrstlose = $hrstlose + 1;
				} else {
					if ($nonep >= 1) {
					#nothing
					$beepnum = 0;
					$hrstlose = $hrstlose + 1;
					} else {
					$addmoney = 5 * $coin;
					$beepnum = 2;
					$hrstwin = $hrstwin + 1;
					}
				}
			} else {
				if ($anycherry3 >= 1) {
					#nothing
					$beepnum = 0;
					$hrstlose = $hrstlose + 1;
				} else {
					if ($nonep >= 1) {
					#nothing
					$beepnum = 0;
					$hrstlose = $hrstlose + 1;
					} else {
					$addmoney = 2 * $coin;
					$beepnum = 2;
					$hrstwin = $hrstwin + 1;
					}
				}
			}
		}
	} elsif ($anydollar == 3) {
		if ($x eq "6166") {
			$addmoney = 125 * $coin;
			$beepnum = 4;
			$hrstwin = $hrstwin + 1;
		} elsif ($x eq "211621") {
			$addmoney = 180 * $coin;
			$beepnum = 4;
			$hrstwin = $hrstwin + 1;
		} elsif ($x eq "21166") {
			$addmoney = 80 * $coin;
			$beepnum = 3;
			$hrstwin = $hrstwin + 1;
		} elsif ($x eq "61621") {
			$addmoney = 80 * $coin;
			$beepnum = 3;
			$hrstwin = $hrstwin + 1;
		} elsif ($x eq "6621") {
			$addmoney = 80 * $coin;
			$beepnum = 3;
			$hrstwin = $hrstwin + 1;
		} elsif ($x eq "2166") {
			$addmoney = 80 * $coin;
			$beepnum = 3;
			$hrstwin = $hrstwin + 1;
		} elsif ($x eq "21621") {
			$addmoney = 80 * $coin;
			$beepnum = 3;
			$hrstwin = $hrstwin + 1;
		} else {
			$beepnum = 0;
			$hrstlose = $hrstlose + 1;
		}
	} elsif ($svslot1 eq '9') {
		if ($hrbonus > 0) {
		#Since this only happens in the bonus round
		#there are never blank spaces
		#thus no need to check for blank reels ($nonep)
			if ($svslot2 eq '9') {
				$addmoney = 10 * $coin;
				$beepnum = 2;
			} else {
				$addmoney = 5 * $coin;
				$beepnum = 2;
			}
			$hrstwin = $hrstwin + 1;
		}
	} else {
		$addmoney = 0;
		$beepnum = 0;
		$hrstlose = $hrstlose + 1;
	}

	$anybar = 0;
	$onecherry = 0;
	$anycherry = 0;
	$anycherry3 = 0;
	$anydollar = 0;
	$nonep = 0;

	if ($startreel == 1) {
		$startreel = 0;
		$addmoney = 0;
	} else {
	}

}

sub fundcalc {
	$money = $money + $addmoney;
	$hrstmc = $hrstmc + $addmoney;
}

sub reel1 {
	$reel = 1;
	if ($reelspin == 3) {
		$slot1 = 'spining';
		$slot2 = 'spining';
		$slot3 = 'spining';
		$slot4 = 'spining';
		$slot5 = 'spining';
		$slot6 = 'spining';
		$slot7 = 'spining';
		$slot8 = 'spining';
		$slot9 = 'spining';
		$slot10 = 'spining';
		$slot11 = 'spining';
		$slot12 = 'spining';
		$slot13 = 'spining';
		$slot14 = 'spining';
	} else {
		$slot1 = $svslot1;
		$slot2 = $svslot1;
		$slot3 = $svslot1;
		$slot4 = $svslot1;
		$slot5 = $svslot1;
		$slot6 = $svslot1;
		$slot7 = $svslot1;
		$slot8 = $svslot1;
		$slot9 = $svslot1;
		$slot10 = $svslot1;
		$slot11 = $svslot1;
		$slot12 = $svslot1;
		$slot13 = $svslot1;
		$slot14 = $svslot1;
	}
}

sub reel2 {
	$reel = 2;
	if ($reelspin >= 2) {
		$slot1 = 'spining';
		$slot2 = 'spining';
		$slot3 = 'spining';
		$slot4 = 'spining';
		$slot5 = 'spining';
		$slot6 = 'spining';
		$slot7 = 'spining';
		$slot8 = 'spining';
		$slot9 = 'spining';
		$slot10 = 'spining';
		$slot11 = 'spining';
		$slot12 = 'spining';
		$slot13 = 'spining';
		$slot14 = 'spining';
	} else {
		$slot1 = $svslot2;
		$slot2 = $svslot2;
		$slot3 = $svslot2;
		$slot4 = $svslot2;
		$slot5 = $svslot2;
		$slot6 = $svslot2;
		$slot7 = $svslot2;
		$slot8 = $svslot2;
		$slot9 = $svslot2;
		$slot10 = $svslot2;
		$slot11 = $svslot2;
		$slot12 = $svslot2;
		$slot13 = $svslot2;
		$slot14 = $svslot2;
	}
}

sub reel3 {
	$reel = 3;
	if ($reelspin >= 1) {
		$slot1 = 'spining';
		$slot2 = 'spining';
		$slot3 = 'spining';
		$slot4 = 'spining';
		$slot5 = 'spining';
		$slot6 = 'spining';
		$slot7 = 'spining';
		$slot8 = 'spining';
		$slot9 = 'spining';
		$slot10 = 'spining';
		$slot11 = 'spining';
		$slot12 = 'spining';
		$slot13 = 'spining';
		$slot14 = 'spining';
	} else {
		$slot1 = $svslot3;
		$slot2 = $svslot3;
		$slot3 = $svslot3;
		$slot4 = $svslot3;
		$slot5 = $svslot3;
		$slot6 = $svslot3;
		$slot7 = $svslot3;
		$slot8 = $svslot3;
		$slot9 = $svslot3;
		$slot10 = $svslot3;
		$slot11 = $svslot3;
		$slot12 = $svslot3;
		$slot13 = $svslot3;
		$slot14 = $svslot3;
	}
}

sub midprint0 {
	midprintbulb0();
}

sub midprint1 {
	print color 'reset';
	print colored('< >',"$boldyellow on_$bgcgreen");
	print color 'reset';
}

sub midprint5 {
	print color 'reset';
	print colored('|',"$boldblack on_$bgcblack");
	print colored('PAY',"$boldblack on_$bgcblack"); print colored('LINE',"$white on_$bgcblack"); print colored('< >',"$boldyellow on_$bgcgreen");
	print color 'reset';
}

sub midprint4 {
	print color 'reset';
	print colored('|       ',"$boldblack on_$bgcblack");
	midprintbulb0();
	print color 'reset';
}

sub midprintbulb0 {
	if ($hrbulbcolor eq 'null') {
		print color 'reset';
		print colored('[ ]',"$boldblack on_$bgcblack");
		print color 'reset';
	} else {
		print color 'reset';
		print colored('[',"$boldblack on_$bgcblack");
		print colored('*',"$hrbulbcolor on_$bgcblack");
		print colored(']',"$boldblack on_$bgcblack");
		print color 'reset';
	}
}

sub midprint4bl1 {
	print color 'reset';
	print colored('| ',"$boldblack on_$bgcblack");
	if ($hrbonushlp > 0) {
	print colored('  x  ',"$boldyellow on_$bgcblack");
	} else {
	print colored('  x  ',"$white on_$bgcblack");
	}
	midprintbulb0();
	print color 'reset';
}

sub midprint4bl2 {
	print color 'reset';
	print colored('| ',"$boldblack on_$bgcblack");
	if ($hrbonushlp > 0) {
	print colored(' xXx ',"$boldyellow on_$bgcblack");
	} else {
	print colored(' xXx ',"$white on_$bgcblack");
	}
	midprintbulb0();
	print color 'reset';
}

sub midprint4bl3 {
	print color 'reset';
	print colored('| ',"$boldblack on_$bgcblack");
	if ($hrbonushlp > 0) {
	print colored(' XXX ',"$boldyellow on_$bgcblack");
	} else {
	print colored(' XXX ',"$white on_$bgcblack");
	}
	midprintbulb0();
	print color 'reset';
}

sub midprint4bl4 {
	print color 'reset';
	print colored('| ',"$boldblack on_$bgcblack");
	if ($hrbonushlp > 0) {
	print colored('  0  ',"$yellow on_$bgcblack");
	} else {
	print colored('  0  ',"$white on_$bgcblack");
	}
	midprintbulb0();
	print color 'reset';
}

sub midprint4bo {
	print color 'reset';
	print colored('| ',"$boldblack on_$bgcblack");
	if ($hrbonus > 0) {
	print colored('BONUS',"$boldgreen on_$bgcblack");
	} else {
	print colored('BONUS',"$boldblack on_$bgcblack");
	}
	print colored(' ',"$boldblack on_$bgcblack");
	midprintbulb0();
	print color 'reset';
}

sub midprint4bn {
	print color 'reset';
	print colored('| ',"$boldblack on_$bgcblack");
	if ($hrbonus > 10000) {
	print colored($hrbonus-1,"$green on_$bgcblack");
	} elsif ($hrbonus > 1000) {
	print colored('0',"$green on_$bgcblack");
	print colored($hrbonus-1,"$green on_$bgcblack");
	} elsif ($hrbonus > 100) {
	print colored('00',"$green on_$bgcblack");
	print colored($hrbonus-1,"$green on_$bgcblack");
	} elsif ($hrbonus > 10) {
	print colored('000',"$green on_$bgcblack");
	print colored($hrbonus-1,"$green on_$bgcblack");
	} elsif ($hrbonus > 0) {
	print colored('0000',"$green on_$bgcblack");
	print colored($hrbonus-1,"$green on_$bgcblack");
	} else {
	print colored('00000',"$white on_$bgcblack");
	}
	print colored(' ',"$boldblack on_$bgcblack");
	midprintbulb0();
	print color 'reset';
}

sub midprint3 {
	print color 'reset';
	print colored('|',"$boldblack on_$bgcblack");
	print colored('PAY',"$white on_$bgcblack"); print colored('LINE',"$boldblack on_$bgcblack");  print colored('< >',"$boldyellow on_$bgcgreen");
	print color 'reset';
}

sub topprint0 {
	print color 'reset';
	print colored('|       ',"$boldblack on_$bgcblack");
	#Over/Under Reel 1
	midprintbulb0(); midprintbulb0(); midprintbulb0(); midprintbulb0();
	midprintbulb0(); midprintbulb0(); midprintbulb0(); midprintbulb0();
	#Over/Under Reel 2
	midprintbulb0(); midprintbulb0(); midprintbulb0(); midprintbulb0();
	midprintbulb0(); midprintbulb0(); midprintbulb0(); midprintbulb0();
	#Over/Under Reel 3
	midprintbulb0(); midprintbulb0(); midprintbulb0(); midprintbulb0();
	midprintbulb0(); midprintbulb0(); midprintbulb0(); midprintbulb0();
	print color 'reset';
}

sub mainscreen {
	topprint0(); print"\n";
	sub sep() { print $SEP; };
	midprint4(); reel1(); sep; slot1(); sep; midprint0(); reel2(); sep; slot1(); sep; midprint0(); reel3(); sep; slot1(); sep; midprint0(); print"\n";
	midprint4(); reel1(); sep; slot2(); sep; midprint0(); reel2(); sep; slot2(); sep; midprint0(); reel3(); sep; slot2(); sep; midprint0(); print"\n";
	midprint4bo(); reel1(); sep; slot3(); sep; midprint0(); reel2(); sep; slot3(); sep; midprint0(); reel3(); sep; slot3(); sep; midprint0(); print"\n";
	midprint4bn(); reel1(); sep; slot4(); sep; midprint0(); reel2(); sep; slot4(); sep; midprint0(); reel3(); sep; slot4(); sep; midprint0(); print"\n";
	midprint4bo(); reel1(); sep; slot5(); sep; midprint0(); reel2(); sep; slot5(); sep; midprint0(); reel3(); sep; slot5(); sep; midprint0(); print"\n";
	midprint4(); reel1(); sep; slot6(); sep; midprint0(); reel2(); sep; slot6(); sep; midprint0(); reel3(); sep; slot6(); sep; midprint0(); print"\n";
	midprint3(); reel1(); sep; slot7(); sep; midprint1(); reel2(); sep; slot7(); sep; midprint1(); reel3(); sep; slot7(); sep; midprint1(); print"\n";
	midprint5(); reel1(); sep; slot8(); sep; midprint1(); reel2(); sep; slot8(); sep; midprint1(); reel3(); sep; slot8(); sep; midprint1(); print"\n";
	midprint4(); reel1(); sep; slot9(); sep; midprint0(); reel2(); sep; slot9(); sep; midprint0(); reel3(); sep; slot9(); sep; midprint0(); print"\n";
	midprint4(); reel1(); sep; slot10(); sep; midprint0(); reel2(); sep; slot10(); sep; midprint0(); reel3(); sep; slot10(); sep; midprint0(); print"\n";
	midprint4(); reel1(); sep; slot11(); sep; midprint0(); reel2(); sep; slot11(); sep; midprint0(); reel3(); sep; slot11(); sep; midprint0(); print"\n";
	midprint4(); reel1(); sep; slot12(); sep; midprint0(); reel2(); sep; slot12(); sep; midprint0(); reel3(); sep; slot12(); sep; midprint0(); print"\n";
	midprint4(); reel1(); sep; slot13(); sep; midprint0(); reel2(); sep; slot13(); sep; midprint0(); reel3(); sep; slot13(); sep; midprint0(); print"\n";
	midprint4(); reel1(); sep; slot14(); sep; midprint0(); reel2(); sep; slot14(); sep; midprint0(); reel3(); sep; slot14(); sep; midprint0(); print"\n";
	topprint0(); print"\n";
}

sub displaywin {
	print colored('|------------------------------------------------------------------------------|',"$boldblack on_$bgcblack");
	print"\n";
	print colored('| ',"$boldblack on_$bgcblack");
	print colored('WINNINGS ',"$boldblack on_$bgcblack");

	print $SEP;
	if ($addmoney > 9999999999) {
	print colored(sprintf("%.4e", $addmoney),"$boldred on_$bgcred");
	} elsif ($addmoney >= 1000000000) {
	print colored("$addmoney","$boldred on_$bgcred");
	} elsif ($addmoney >= 100000000) {
	print colored(" $addmoney","$boldred on_$bgcred");
	} elsif ($addmoney >= 10000000) {
	print colored("  $addmoney","$boldred on_$bgcred");
	} elsif ($addmoney >= 1000000) {
	print colored("   $addmoney","$boldred on_$bgcred");
	} elsif ($addmoney >= 100000) {
	print colored("    $addmoney","$boldred on_$bgcred");
	} elsif ($addmoney >= 10000) {
	print colored("     $addmoney","$boldred on_$bgcred");
	} elsif ($addmoney >= 1000) {
	print colored("      $addmoney","$boldred on_$bgcred");
	} elsif ($addmoney >= 100) {
	print colored("       $addmoney","$boldred on_$bgcred");
	} elsif ($addmoney >= 10) {
	print colored("        $addmoney","$boldred on_$bgcred");
	} elsif ($addmoney >= 1) {
	print colored("         $addmoney","$boldred on_$bgcred");
	} else {
	print colored("         $addmoney","$boldred on_$bgcred");
	}
	print $SEP;

	print colored(' TOTAL FUNDS ',"$boldblack on_$bgcblack");
	
	print $SEP;
	if ($money > 9999999999) {
	print colored(sprintf("%.4e", $money),"$boldgreen on_$bgcgreen");
	} elsif ($money >= 1000000000) {
	print colored("$money","$boldgreen on_$bgcgreen");
	} elsif ($money >= 100000000) {
	print colored(" $money","$boldgreen on_$bgcgreen");
	} elsif ($money >= 10000000) {
	print colored("  $money","$boldgreen on_$bgcgreen");
	} elsif ($money >= 1000000) {
	print colored("   $money","$boldgreen on_$bgcgreen");
	} elsif ($money >= 100000) {
	print colored("    $money","$boldgreen on_$bgcgreen");
	} elsif ($money >= 10000) {
	print colored("     $money","$boldgreen on_$bgcgreen");
	} elsif ($money >= 1000) {
	print colored("      $money","$boldgreen on_$bgcgreen");
	} elsif ($money >= 100) {
	print colored("       $money","$boldgreen on_$bgcgreen");
	} elsif ($money >= 10) {
	print colored("        $money","$boldgreen on_$bgcgreen");
	} elsif ($money >= 1) {
	print colored("         $money","$boldgreen on_$bgcgreen");
	} else {
	print colored("         $money","$boldgreen on_$bgcgreen");
	}
	print $SEP;
							    #
	print colored('       INSERT TOKEN ',"$boldyellow on_$bgcblack");	
	print $SEP;
	print colored(' ---------- ',"$black on_$bgcyellow");					    
	print $SEP;
	print colored('   |',"$boldblack on_$bgcblack");
	beepalrm();
	
	print colored('|------------------------------------------------------------------------------|',"$boldblack on_$bgcblack"); print"\n";	
	print colored('|',"$boldblack on_$bgcblack");  
	print colored('                            HOUSE RULES REEL DEAL                             ',"$boldblue on_$bgcblue"); 
	print colored('|',"$boldblack on_$bgcblack"); beepalrm();
	
	print colored('|',"$boldblack on_$bgcblack");
	print colored(' GNU GNU GNU ',"$boldblue on_$bgcblue"); print colored('= 10000 ',"$boldwhite on_$bgcblue"); 
	print colored('  * ',"$red on_$bgcblue"); print colored('  * ',"$white on_$bgcblue"); 
	print colored('  *  ',"$boldblue on_$bgcblue"); print colored('= 62  ',"$boldwhite on_$bgcblue");
	print colored('BAR',"$boldyellow on_$bgcblack"); print colored(' ',"$boldblack on_$bgcblue");
	print colored('BAR',"$boldyellow on_$bgcblack"); print colored(' ',"$boldblack on_$bgcblue");
	print colored('BAR',"$boldmagenta on_$bgcblack"); print colored(' ',"$boldblack on_$bgcblue");
	print colored('= 600   ',"$boldwhite on_$bgcblue");
	print colored('BAR',"$cyan on_$bgcblack"); print colored(' ',"$boldblack on_$bgcblue");
	print colored('BAR',"$cyan on_$bgcblack"); print colored(' ',"$boldblack on_$bgcblue");
	print colored(' $  ',"$green on_$bgcblue");
	print colored('= 20',"$boldwhite on_$bgcblue");	
	print colored('  ',"$boldwhite on_$bgcblue");
	print colored('|',"$boldblack on_$bgcblack"); beepalrm();
	
	print colored('|',"$boldblack on_$bgcblack"); 
	print colored('  7   7   7  ',"$red on_$bgcblue"); print colored('= 2000  ',"$boldwhite on_$bgcblue");
	print colored('  O   O   O  ',"$magenta on_$bgcblue"); print colored('= 40  ',"$boldwhite on_$bgcblue");
	print colored('BAR',"$boldyellow on_$bgcblack"); print colored(' ',"$boldblack on_$bgcblue");
	print colored('BAR',"$boldyellow on_$bgcblack"); print colored(' ',"$boldblack on_$bgcblue");
	print colored('BAR',"$cyan on_$bgcblack"); print colored(' ',"$boldblack on_$bgcblue");
	print colored('= 450   ',"$boldwhite on_$bgcblue");
	print colored('BAR',"$cyan on_$bgcblack"); print colored(' ',"$boldblack on_$bgcblue");
	print colored('BAR',"$cyan on_$bgcblack"); print colored(' ',"$boldblack on_$bgcblue");
	print colored(' *  ',"$boldblue on_$bgcblue");
	print colored('= 18',"$boldwhite on_$bgcblue");	
	print colored('  ',"$boldwhite on_$bgcblue");
	print colored('|',"$boldblack on_$bgcblack"); beepalrm();
	
	print colored('|',"$boldblack on_$bgcblack"); print colored(' ',"$boldblack on_$bgcblue");
	print colored('BAR',"$boldyellow on_$bgcblack"); print colored(' ',"$boldblack on_$bgcblue");
	print colored('BAR',"$boldyellow on_$bgcblack"); print colored(' ',"$boldblack on_$bgcblue");
	print colored('BAR',"$boldyellow on_$bgcblack"); print colored(' ',"$boldblack on_$bgcblue");
	print colored('= 1000  ',"$boldwhite on_$bgcblue");
	print colored(' BEL BEL BEL ',"$boldyellow on_$bgcblue"); print colored('= 25  ',"$boldwhite on_$bgcblue");
	print colored('BAR',"$boldmagenta on_$bgcblack"); print colored(' ',"$boldblack on_$bgcblue");
	print colored('BAR',"$boldmagenta on_$bgcblack"); print colored(' ',"$boldblack on_$bgcblue");
	print colored('BAR',"$cyan on_$bgcblack"); print colored(' ',"$boldblack on_$bgcblue");
	print colored('= 200   ',"$boldwhite on_$bgcblue");
	print colored('BAR',"$cyan on_$bgcblack"); print colored(' ',"$boldblack on_$bgcblue");
	print colored('BAR',"$cyan on_$bgcblack"); print colored(' ',"$boldblack on_$bgcblue");
	print colored(' O  ',"$magenta on_$bgcblue");
	print colored('= 16',"$boldwhite on_$bgcblue");	
	print colored('  ',"$boldwhite on_$bgcblue");
	print colored('|',"$boldblack on_$bgcblack"); beepalrm();
	
	print colored('|',"$boldblack on_$bgcblack"); print colored(' ',"$boldblack on_$bgcblue");
	print colored('BAR',"$boldmagenta on_$bgcblack"); print colored(' ',"$boldblack on_$bgcblue");
	print colored('BAR',"$boldmagenta on_$bgcblack"); print colored(' ',"$boldblack on_$bgcblue");
	print colored('BAR',"$boldmagenta on_$bgcblack"); print colored(' ',"$boldblack on_$bgcblue"); 	
	print colored('= 300   ',"$boldwhite on_$bgcblue");
	print colored('  C   C   C  ',"$boldred on_$bgcblue"); print colored('= 10 ',"$boldwhite on_$bgcblue");
	print colored('  ANYBAR x3  ',"$white on_$bgcblue"); print colored('= 22    ',"$boldwhite on_$bgcblue");
	print colored('BAR',"$cyan on_$bgcblack"); print colored(' ',"$boldblack on_$bgcblue");
	print colored('BAR',"$cyan on_$bgcblack"); print colored(' ',"$boldblack on_$bgcblue");
	print colored('BEL ',"$boldyellow on_$bgcblue");
	print colored('= 14',"$boldwhite on_$bgcblue");	
	print colored('  ',"$boldwhite on_$bgcblue"); 
	print colored('|',"$boldblack on_$bgcblack"); beepalrm();
	
	print colored('|',"$boldblack on_$bgcblack"); print colored(' ',"$boldblack on_$bgcblue");
	print colored('BAR',"$cyan on_$bgcblack"); print colored(' ',"$boldblack on_$bgcblue");
	print colored('BAR',"$cyan on_$bgcblack"); print colored(' ',"$boldblack on_$bgcblue");
	print colored('BAR',"$cyan on_$bgcblack"); print colored(' ',"$boldblack on_$bgcblue"); 	 
	print colored('= 150   ',"$boldwhite on_$bgcblue");
	print colored('  C   C ',"$boldred on_$bgcblue"); print colored(' ANY ',"$white on_$bgcblue"); 
	print colored('= 5   ',"$boldwhite on_$bgcblue");
	print colored(' $   ',"$green on_$bgcblue"); print colored('$',"$boldyellow on_$bgcblue"); print colored('   $  ',"$green on_$bgcblue"); print colored('= 125   ',"$boldwhite on_$bgcblue");
	print colored('BAR',"$cyan on_$bgcblack"); print colored(' ',"$boldblack on_$bgcblue");
	print colored('BAR',"$cyan on_$bgcblack"); print colored(' ',"$boldblack on_$bgcblue");
	print colored(' C  ',"$boldred on_$bgcblue");
	print colored('= 12',"$boldwhite on_$bgcblue");	
	print colored('  ',"$boldwhite on_$bgcblue"); 
	print colored('|',"$boldblack on_$bgcblack"); beepalrm();
	
	print colored('|',"$boldblack on_$bgcblack"); 
	print colored('  $   $   $  ',"$green on_$bgcblue"); print colored('= 80    ',"$boldwhite on_$bgcblue");
	print colored('  C  ',"$boldred on_$bgcblue"); print colored('ANY ANY ',"$white on_$bgcblue"); print colored('= 2   ',"$boldwhite on_$bgcblue"); 
	print colored(' $   ',"$boldwhite on_$bgcblue"); print colored('$',"$boldyellow on_$bgcblue"); print colored('   $  ',"$boldwhite on_$bgcblue"); print colored('= 180   ',"$boldwhite on_$bgcblue");	
	print colored('B',"$boldyellow on_$bgcmagenta"); 
	print colored('N',"$boldyellow on_$bgccyan");
	print colored('S',"$boldyellow on_$bgcmagenta");
	print colored(' ',"$boldblack on_$bgcblue");
	print colored('B',"$boldyellow on_$bgcmagenta"); 
	print colored('N',"$boldyellow on_$bgccyan");
	print colored('S',"$boldyellow on_$bgcmagenta");
	print colored(' ',"$boldblack on_$bgcblue");
	print colored('B',"$boldyellow on_$bgcmagenta"); 
	print colored('N',"$boldyellow on_$bgccyan");
	print colored('S',"$boldyellow on_$bgcmagenta");
	print colored(' = 15  ',"$boldwhite on_$bgcblue");
	print colored('|',"$boldblack on_$bgcblack"); beepalrm();
	
	print colored('\\------------------------------------------------------------------------------/',"$boldblack on_$bgcblack"); beepalrm();
	
	$beepnum = 0;
}

sub topscreen {
	print colored(' ______________________________________________________________________________ ',"$boldblack on_$bgcblack"); print"\n";
	print colored('/ GPC-SLOTS 2',"$boldblack on_$bgcblack"); print colored('            P = play   C = Return To Casino Menu   EXIT = quit',"$white on_$bgcblack"); print colored('    \\',"$boldblack on_$bgcblack"); print"\n";	
}

################################################################################################################################
## GENRE: Slot Mahine
## NAME: Double Blue Diamond
## AUTHOR: MikeeUSA

sub ddmain {
	ddresetvars();
	ddspinreel();
	ddreeltrans();
	
	if ($animate == 1) {
		$ddreelspin = 3;
		ddtopprint();
		ddmainscreen();
		smallpause();
		newlines();
	
		$ddreelspin = 2;
		ddtopprint();
		ddmainscreen();
		tinypause();
		newlines();
	
		$ddreelspin = 1;
		ddtopprint();
		ddmainscreen();
		tinypause();
		newlines();
	}
	
	$ddreelspin = 0;
	ddtopprint();
	$ddx = $ddsvslot1.$ddsvslot2.$ddsvslot3;
	ddaddmoney();
	ddfundcalc();
	ddmainscreen();
	ptracker();
	ddstartinfo();	
}

sub ddmain2 {
	ddresetvars();
	ddreeltrans();
	ddtopprint();
	$ddx = ' '; #keep, a reset to null type job... well not quite null.
	##ddaddmoney(); #Relic from the dark ages, Don't uncomment.
	ddmainscreen();
	ddstartinfo();	
}

sub ddresetvars {
	$ddreelspin = 0;
}

sub ddstartinfo {
	tokeneval();
	$ddstartinfo = <STDIN>;
	chomp($ddstartinfo);

	if (($ddstartinfo eq 'a') or ($ddstartinfo eq 'A')) {
		$ddstartinfo = $ddagaincmd;
	} elsif  (($ddstartinfo eq 'p') or ($ddstartinfo eq 'P') or ($ddstartinfo eq '1p') or ($ddstartinfo eq '1P')) {
		$ddagaincmd = $ddstartinfo;
	} else {
		#Do Nothing		
	}

	if (($ddstartinfo eq 'p') or ($ddstartinfo eq 'P') or ($ddstartinfo eq '1p') or ($ddstartinfo eq '1P')) {
		if ($money >= $coin) {
			$money = $money - $coin;
			$moneyexp = $moneyexp + $coin;
			$ddstmc2 = $ddstmc2 + $coin;
			$spins = $spins + 1;
			$ddstspins = $ddstspins + 1;
			if ($proadd == 1) {
				$projkpot = $projkpot + $coin;
				$proadd = 0;
			} else {
				$proadd = 1;
			}
			newlines();
			ddmain();
		} else {
			newlines();
			ddmain2();		
		}
	} elsif (($ddstartinfo eq 'exit') or ($ddstartinfo eq 'EXIT') or ($ddstartinfo eq 'quit') or ($ddstartinfo eq 'QUIT')) {
		exitgame();
	} elsif (($ddstartinfo eq 'c') or ($ddstartinfo eq 'C')) {
		return;
	} else {
		newlines();
		ddmain2();
	}

}

sub ddfundcalc {
	$money = $money + $ddaddmoney;
	$ddstmc = $ddstmc + $ddaddmoney;
}
	
sub ddslot2dia2  { if ($ddslot2 == 1) {$ddcolor = "bold $ddcolor"; } elsif ($ddslot2 == 11) {$ddcolor = "bold $ddcolor"; } else { } print colored('   ___________  ',"$ddcolor on_$bgcwhite"); }
sub ddslot2dia3  { if ($ddslot3 == 1) {$ddcolor = "bold $ddcolor"; } elsif ($ddslot3 == 11) {$ddcolor = "bold $ddcolor"; } else { $ddcolort = "$boldblack"; } print colored(' _/_____|_____\ ',"$ddcolor on_$bgcwhite"); }
sub ddslot2dia4  { $ddcolort = $ddcolor; if ($ddslot4 == 1) {$ddcolor = "bold $ddcolor"; } elsif ($ddslot4 == 11) {$ddcolor = "bold $ddcolor"; } else { $ddcolort = "$boldblack"; } print colored('/_____|_____\\',"$ddcolor on_$bgcwhite"); print colored(' / ',"$ddcolort on_$bgcwhite"); }
sub ddslot2dia5  { $ddcolort = $ddcolor; if ($ddslot5 == 1) {$ddcolor = "bold $ddcolor"; } elsif ($ddslot5 == 11) {$ddcolor = "bold $ddcolor"; } else { $ddcolort = "$boldblack"; } print colored('\\** * ',"$ddcolor on_$bgcwhite"); print colored('|0   0//  ',"$ddcolort on_$bgcwhite"); }
sub ddslot2dia6  { $ddcolort = $ddcolor; if ($ddslot6 == 1) {$ddcolor = "bold $ddcolor"; } elsif ($ddslot6 == 11) {$ddcolor = "bold $ddcolor"; } else { $ddcolort = "$boldblack"; } print colored(' \\ * *',"$ddcolor on_$bgcwhite"); print colored('| 0 0//   ',"$ddcolort on_$bgcwhite"); }
sub ddslot2dia7  { $ddcolort = $ddcolor; if ($ddslot7 == 1) {$ddcolor = "bold $ddcolor"; } elsif ($ddslot7 == 11) {$ddcolor = "bold $ddcolor"; } else { $ddcolort = "$boldblack"; } print colored('  \\ **',"$ddcolor on_$bgcwhite"); print colored('| 00//    ',"$ddcolort on_$bgcwhite"); }
sub ddslot2dia8  { $ddcolort = $ddcolor; if ($ddslot8 == 1) {$ddcolor = "bold $ddcolor"; } elsif ($ddslot8 == 11) {$ddcolor = "bold $ddcolor"; } else { $ddcolort = "$boldblack"; } print colored('   \\* ',"$ddcolor on_$bgcwhite"); print colored('|  //     ',"$ddcolort on_$bgcwhite"); }
sub ddslot2dia9  { $ddcolort = $ddcolor; if ($ddslot9 == 1) {$ddcolor = "bold $ddcolor"; } elsif ($ddslot9 == 11) {$ddcolor = "bold $ddcolor"; } else { $ddcolort = "$boldblack"; } print colored('    \\*',"$ddcolor on_$bgcwhite"); print colored('|0//      ',"$ddcolort on_$bgcwhite"); }
sub ddslot2dia10 { $ddcolort = $ddcolor; if ($ddslot10 == 1) {$ddcolor = "bold $ddcolor";} elsif ($ddslot10 == 11) {$ddcolor = "bold $ddcolor"; } else { $ddcolort = "$boldblack";} print colored('     \\',"$ddcolor on_$bgcwhite"); print colored('|/        ',"$ddcolort on_$bgcwhite"); }

sub ddslot1dia3  { print colored('  ___________   ',"$ddcolor on_$bgcwhite"); }
sub ddslot1dia4  { print colored(' /_____|_____\\  ',"$ddcolor on_$bgcwhite"); }
sub ddslot1dia5  { $ddcolort = "$boldblack"; print colored(' \\**  *',"$ddcolor on_$bgcwhite"); print colored('| 0  0/  ',"$ddcolort on_$bgcwhite"); }
sub ddslot1dia6  { $ddcolort = "$boldblack"; print colored('  \\ * *',"$ddcolor on_$bgcwhite"); print colored('|  00/   ',"$ddcolort on_$bgcwhite"); }
sub ddslot1dia7  { $ddcolort = "$boldblack"; print colored('   \\ * ',"$ddcolor on_$bgcwhite"); print colored('|0  /    ',"$ddcolort on_$bgcwhite"); }
sub ddslot1dia8  { $ddcolort = "$boldblack"; print colored('    \\ *',"$ddcolor on_$bgcwhite"); print colored('| 0/     ',"$ddcolort on_$bgcwhite"); }
sub ddslot1dia9  { $ddcolort = "$boldblack"; print colored('     \\*',"$ddcolor on_$bgcwhite"); print colored('| /      ',"$ddcolort on_$bgcwhite"); }
sub ddslot1dia10 { $ddcolort = "$boldblack"; print colored('      \\',"$ddcolor on_$bgcwhite"); print colored('|/       ',"$ddcolort on_$bgcwhite"); }

sub ddslot1jwl3  { print colored('    _______     ',"bold $ddcolor on_$bgcwhite"); }
sub ddslot1jwl4  { print colored('   /\\* ***/',"bold $ddcolor on_$bgcwhite"); print colored('\\    ',"$ddcolor on_$bgcwhite"); }
sub ddslot1jwl5  { print colored('  /__\\___/',"bold $ddcolor on_$bgcwhite"); print colored('__\\   ',"$ddcolor on_$bgcwhite"); }
sub ddslot1jwl6  { print colored('  | *|',"bold $ddcolor on_$bgcwhite"); print colored('  0|  |   ',"$ddcolor on_$bgcwhite"); }
sub ddslot1jwl7  { print colored('  |* |',"bold $ddcolor on_$bgcwhite"); print colored('0  |  |   ',"$ddcolor on_$bgcwhite"); }
sub ddslot1jwl8  { print colored('  |__|',"bold $ddcolor on_$bgcwhite"); print colored('___|__|   ',"$ddcolor on_$bgcwhite"); }
sub ddslot1jwl9  { print colored('  \ */   \  /   ',"$ddcolor on_$bgcwhite"); }
sub ddslot1jwl10 { print colored('   \/_____\/    ',"$ddcolor on_$bgcwhite"); }

sub ddslot1emr2  { print colored('      /|',"bold $ddcolor on_$bgcwhite"); print colored('\       ',"$ddcolor on_$bgcwhite"); }
sub ddslot1emr3  { print colored('     /*|',"bold $ddcolor on_$bgcwhite"); print colored('*\      ',"$ddcolor on_$bgcwhite"); }
sub ddslot1emr4  { print colored('    /*/',"bold $ddcolor on_$bgcwhite"); print colored('0\ \     ',"$ddcolor on_$bgcwhite"); }
sub ddslot1emr5  { print colored('   /*/',"bold $ddcolor on_$bgcwhite"); print colored('0 0\*\    ',"$ddcolor on_$bgcwhite"); }
sub ddslot1emr6  { print colored('  /_/',"bold $ddcolor on_$bgcwhite"); print colored('0 000\_\   ',"$ddcolor on_$bgcwhite"); }
sub ddslot1emr7  { print colored('  \*\000 0/*/   ',"$ddcolor on_$bgcwhite"); }
sub ddslot1emr8  { print colored('   \ \ 00/*/    ',"$ddcolor on_$bgcwhite"); }
sub ddslot1emr9  { print colored('    \*\0/ /     ',"$ddcolor on_$bgcwhite"); }
sub ddslot1emr10 { print colored('     \ |*/      ',"$ddcolor on_$bgcwhite"); }
sub ddslot1emr11 { print colored('      \|/       ',"$ddcolor on_$bgcwhite"); }

sub ddslot1gnt4 { print colored('  ___________   ',"$ddcolor on_$bgcwhite"); }
sub ddslot1gnt5 { print colored(' |\ _______ /|  ',"$ddcolor on_$bgcwhite"); }
sub ddslot1gnt6 { print colored(' |*| 00  00|*|  ',"$ddcolor on_$bgcwhite"); }
sub ddslot1gnt7 { print colored(' |*|00 00 0|*|  ',"$ddcolor on_$bgcwhite"); }
sub ddslot1gnt8 { print colored(' |*|_______|*|  ',"$ddcolor on_$bgcwhite"); }
sub ddslot1gnt9 { print colored(' |/_________\|  ',"$ddcolor on_$bgcwhite"); }

sub ddslot1crs1  { print colored('      /|',"bold $ddcolor on_$bgcwhite"); print colored('\       ',"$ddcolor on_$bgcwhite"); }
sub ddslot1crs2  { print colored('     /*|',"bold $ddcolor on_$bgcwhite"); print colored('0\      ',"$ddcolor on_$bgcwhite"); }
sub ddslot1crs3  { print colored('    /__|',"bold $ddcolor on_$bgcwhite"); print colored('__\     ',"$ddcolor on_$bgcwhite"); }
sub ddslot1crs4  { print colored('    |**|',"bold $ddcolor on_$bgcwhite"); print colored(' 0|     ',"$ddcolor on_$bgcwhite"); }
sub ddslot1crs5  { print colored('    |* |',"bold $ddcolor on_$bgcwhite"); print colored('0 |     ',"$ddcolor on_$bgcwhite"); }
sub ddslot1crs6  { print colored('    | *|',"bold $ddcolor on_$bgcwhite"); print colored(' 0|     ',"$ddcolor on_$bgcwhite"); }
sub ddslot1crs7  { print colored('    |__|',"bold $ddcolor on_$bgcwhite"); print colored('__|     ',"$ddcolor on_$bgcwhite"); }
sub ddslot1crs8  { print colored('    \* | 0/     ',"$ddcolor on_$bgcwhite"); }
sub ddslot1crs9  { print colored('     \*|0/      ',"$ddcolor on_$bgcwhite"); }
sub ddslot1crs10 { print colored('      \|/       ',"$ddcolor on_$bgcwhite"); }

sub ddslotwhite { print colored('                ',"$ddcolor on_$bgcwhite"); }

sub ddslotspining { print colored('||||||||||||||||',"$boldwhite on_$bgcwhite"); }

sub ddspinreel {
	$ddslotsymbol1 = int(rand(56));
	$ddslotsymbol2 = int(rand(56));
	$ddslotsymbol3 = int(rand(56));
}

sub ddreeltrans {
	if ($ddslotsymbol1 <= 12) {
		$ddsvslot1 = 7;
		$ddr1color = "$black";
	} elsif ($ddslotsymbol1 <= 22) {
		$ddsvslot1 = 6;
		$ddr1color = "$boldyellow";
	} elsif ($ddslotsymbol1 <= 30) {
		$ddsvslot1 = 5;
		$ddr1color = "$green";
	} elsif ($ddslotsymbol1 <= 36) {
		$ddsvslot1 = 4;
		$ddr1color = "$red";
	} elsif ($ddslotsymbol1 <= 40) {
		$ddsvslot1 = 3;
		$ddr1color = "$boldwhite";
	} elsif ($ddslotsymbol1 <= 42) {
		$ddsvslot1 = 2;
		$ddr1color = "$boldwhite";
	} elsif ($ddslotsymbol1 <= 43) {
		$ddsvslot1 = 1;
		$ddr1color = "$blue";
	} elsif ($ddslotsymbol1 <= 46) {
		$ddsvslot1 = 8;
		$ddr1color = "$white";
	} elsif ($ddslotsymbol1 <= 49) {
		$ddsvslot1 = 9;
		$ddr1color = "$white";
	} elsif ($ddslotsymbol1 <= 52) {
		$ddsvslot1 = 10;
		$ddr1color = "$white";
	} elsif ($ddslotsymbol1 <= 55) {
		$ddsvslot1 = 11;
		$ddr1color = "$white";				
	} else {
		$ddsvslot1 = 0;
		$ddr1color = "$white";
	}
	
	if ($ddslotsymbol2 <= 12) {
		$ddsvslot2 = 7;
		$ddr2color = "$black";
	} elsif ($ddslotsymbol2 <= 22) {
		$ddsvslot2 = 6;
		$ddr2color = "$boldyellow";
	} elsif ($ddslotsymbol2 <= 30) {
		$ddsvslot2 = 5;
		$ddr2color = "$green";
	} elsif ($ddslotsymbol2 <= 36) {
		$ddsvslot2 = 4;
		$ddr2color = "$red";
	} elsif ($ddslotsymbol2 <= 40) {
		$ddsvslot2 = 3;
		$ddr2color = "$boldwhite";
	} elsif ($ddslotsymbol2 <= 42) {
		$ddsvslot2 = 2;
		$ddr2color = "$boldwhite";
	} elsif ($ddslotsymbol2 <= 43) {
		$ddsvslot2 = 1;
		$ddr2color = "$blue";
	} elsif ($ddslotsymbol2 <= 46) {
		$ddsvslot2 = 8;
		$ddr2color = "$white";
	} elsif ($ddslotsymbol2 <= 49) {
		$ddsvslot2 = 9;
		$ddr2color = "$white";
	} elsif ($ddslotsymbol2 <= 52) {
		$ddsvslot2 = 10;
		$ddr2color = "$white";
	} elsif ($ddslotsymbol2 <= 55) {
		$ddsvslot2 = 11;
		$ddr2color = "$white";	
	} else {
		$ddsvslot2 = 0;
		$ddr2color = "$white";
	}
	
	if ($ddslotsymbol3 <= 12) {
		$ddsvslot3 = 7;
		$ddr3color = "$black";
	} elsif ($ddslotsymbol3 <= 22) {
		$ddsvslot3 = 6;
		$ddr3color = "$boldyellow";
	} elsif ($ddslotsymbol3 <= 30) {
		$ddsvslot3 = 5;
		$ddr3color = "$green";
	} elsif ($ddslotsymbol3 <= 36) {
		$ddsvslot3 = 4;
		$ddr3color = "$red";
	} elsif ($ddslotsymbol3 <= 40) {
		$ddsvslot3 = 3;
		$ddr3color = "$boldwhite";
	} elsif ($ddslotsymbol3 <= 42) {
		$ddsvslot3 = 2;
		$ddr3color = "$boldwhite";
	} elsif ($ddslotsymbol3 <= 43) {
		$ddsvslot3 = 1;
		$ddr3color = "$blue";
	} elsif ($ddslotsymbol3 <= 46) {
		$ddsvslot3 = 8;
		$ddr3color = "$white";
	} elsif ($ddslotsymbol3 <= 49) {
		$ddsvslot3 = 9;
		$ddr3color = "$white";
	} elsif ($ddslotsymbol3 <= 52) {
		$ddsvslot3 = 10;
		$ddr3color = "$white";
	} elsif ($ddslotsymbol3 <= 55) {
		$ddsvslot3 = 11;
		$ddr3color = "$white";		
	} else {
		$ddsvslot3 = 0;
		$ddr3color = "$white";
	}		


}


					
sub ddslot1 {
	if ($ddslot1 eq 'spining') {
		ddslotspining();
	} elsif ($ddslot1 == 7) {
		ddslot1crs1();
	} elsif ($ddslot1 == 8) {
		$ddcolor = "$black"; ddslot1crs8();
	} elsif ($ddslot1 == 9) {
		$ddcolor = "$green"; ddslot1emr8();
	} elsif ($ddslot1 == 10) {
		$ddcolor = "$boldyellow"; ddslot1gnt7();
	} elsif ($ddslot1 == 11) {
		$ddcolor = "$blue"; ddslot2dia8();			
	} else {
		ddslotwhite();
	}

}

sub ddslot2 {
	if ($ddslot2 eq 'spining') {
		ddslotspining();
	} elsif ($ddslot2 == 1) {
		ddslot2dia2();
	} elsif ($ddslot2 == 2) {
		ddslot2dia2();	
	} elsif ($ddslot2 == 5) {
		ddslot1emr2();	
	} elsif ($ddslot2 == 7) {
		ddslot1crs2();
	} elsif ($ddslot2 == 8) {
		$ddcolor = "$black"; ddslot1crs9();
	} elsif ($ddslot2 == 9) {
		$ddcolor = "$green"; ddslot1emr9();
	} elsif ($ddslot2 == 10) {
		$ddcolor = "$boldyellow"; ddslot1gnt8();
	} elsif ($ddslot1 == 11) {
		$ddcolor = "$blue"; ddslot2dia9();		
	} else {
		ddslotwhite();
	}

}

sub ddslot3 {
	if ($ddslot3 eq 'spining') {
		ddslotspining();
	} elsif ($ddslot3 == 1) {
		ddslot2dia3();
	} elsif ($ddslot3 == 2) {
		ddslot2dia3();	
	} elsif ($ddslot3 == 3) {
		ddslot1dia3();
	} elsif ($ddslot3 == 4) {
		ddslot1jwl3();	
	} elsif ($ddslot3 == 5) {
		ddslot1emr3();	
	} elsif ($ddslot3 == 7) {
		ddslot1crs3();
	} elsif ($ddslot3 == 8) {
		$ddcolor = "$black"; ddslot1crs10();
	} elsif ($ddslot3 == 9) {
		$ddcolor = "$green"; ddslot1emr10();
	} elsif ($ddslot3 == 10) {
		$ddcolor = "$boldyellow"; ddslot1gnt9();
	} elsif ($ddslot1 == 11) {
		$ddcolor = "$blue"; ddslot2dia10();		
	} else {
		ddslotwhite();
	}

}

sub ddslot4 {
	if ($ddslot4 eq 'spining') {
		ddslotspining();
	} elsif ($ddslot4 == 1) {
		ddslot2dia4();
	} elsif ($ddslot4 == 2) {
		ddslot2dia4();	
	} elsif ($ddslot4 == 3) {
		ddslot1dia4();
	} elsif ($ddslot4 == 4) {
		ddslot1jwl4();	
	} elsif ($ddslot4 == 5) {
		ddslot1emr4();
	} elsif ($ddslot4 == 6) {
		ddslot1gnt4();		
	} elsif ($ddslot4 == 7) {
		ddslot1crs4();
	} elsif ($ddslot4 == 9) {
		$ddcolor = "$green"; ddslot1emr11();	
	} else {
		ddslotwhite();
	}

}

sub ddslot5 {
	if ($ddslot5 eq 'spining') {
		ddslotspining();
	} elsif ($ddslot5 == 1) {
		ddslot2dia5();
	} elsif ($ddslot5 == 2) {
		ddslot2dia5();	
	} elsif ($ddslot5 == 3) {
		ddslot1dia5();
	} elsif ($ddslot5 == 4) {
		ddslot1jwl5();	
	} elsif ($ddslot5 == 5) {
		ddslot1emr5();
	} elsif ($ddslot5 == 6) {
		ddslot1gnt5();		
	} elsif ($ddslot5 == 7) {
		ddslot1crs5();
	} else {
		ddslotwhite();
	}

}

sub ddslot6 {
	if ($ddslot6 eq 'spining') {
		ddslotspining();
	} elsif ($ddslot6 == 1) {
		ddslot2dia6();
	} elsif ($ddslot6 == 2) {
		ddslot2dia6();	
	} elsif ($ddslot6 == 3) {
		ddslot1dia6();
	} elsif ($ddslot6 == 4) {
		ddslot1jwl6();	
	} elsif ($ddslot6 == 5) {
		ddslot1emr6();
	} elsif ($ddslot6 == 6) {
		ddslot1gnt6();		
	} elsif ($ddslot6 == 7) {
		ddslot1crs6();
	} else {
		ddslotwhite();
	}

}

sub ddslot7 {
	if ($ddslot7 eq 'spining') {
		ddslotspining();
	} elsif ($ddslot7 == 1) {
		ddslot2dia7();
	} elsif ($ddslot7 == 2) {
		ddslot2dia7();	
	} elsif ($ddslot7 == 3) {
		ddslot1dia7();
	} elsif ($ddslot7 == 4) {
		ddslot1jwl7();	
	} elsif ($ddslot7 == 5) {
		ddslot1emr7();
	} elsif ($ddslot7 == 6) {
		ddslot1gnt7();		
	} elsif ($ddslot7 == 7) {
		ddslot1crs7();
	} elsif ($ddslot7 == 11) {
		$ddcolor = "$black"; ddslot1crs1();
	} else {
		ddslotwhite();
	}

}

sub ddslot8 {
	if ($ddslot8 eq 'spining') {
		ddslotspining();
	} elsif ($ddslot8 == 1) {
		ddslot2dia8();
	} elsif ($ddslot8 == 2) {
		ddslot2dia8();	
	} elsif ($ddslot8 == 3) {
		ddslot1dia8();
	} elsif ($ddslot8 == 4) {
		ddslot1jwl8();	
	} elsif ($ddslot8 == 5) {
		ddslot1emr8();
	} elsif ($ddslot8 == 6) {
		ddslot1gnt8();		
	} elsif ($ddslot8 == 7) {
		ddslot1crs8();
	} elsif ($ddslot8 == 11) {
		$ddcolor = "$black"; ddslot1crs2();
	} else {
		ddslotwhite();
	}

}

sub ddslot9 {
	if ($ddslot9 eq 'spining') {
		ddslotspining();
	} elsif ($ddslot9 == 1) {
		ddslot2dia9();
	} elsif ($ddslot9 == 2) {
		ddslot2dia9();	
	} elsif ($ddslot9 == 3) {
		ddslot1dia9();
	} elsif ($ddslot9 == 4) {
		ddslot1jwl9();	
	} elsif ($ddslot9 == 5) {
		ddslot1emr9();
	} elsif ($ddslot9 == 6) {
		ddslot1gnt9();		
	} elsif ($ddslot9 == 7) {
		ddslot1crs9();
	} elsif ($ddslot9 == 8) {
		$ddcolor = "$red"; ddslot1jwl3();
	} elsif ($ddslot9 == 9) {	
		$ddcolor = "$boldwhite"; ddslot1dia3();		
	} elsif ($ddslot9 == 10) {	
		$ddcolor = "$boldwhite"; ddslot1dia3();
	} elsif ($ddslot9 == 11) {
		$ddcolor = "$black"; ddslot1crs3();		
	} else {
		ddslotwhite();
	}

}

sub ddslot10 {
	if ($ddslot10 eq 'spining') {
		ddslotspining();
	} elsif ($ddslot10 == 1) {
		ddslot2dia10();
	} elsif ($ddslot10 == 2) {
		ddslot2dia10();	
	} elsif ($ddslot10 == 3) {
		ddslot1dia10();
	} elsif ($ddslot10 == 4) {
		ddslot1jwl10();	
	} elsif ($ddslot10 == 5) {
		ddslot1emr10();		
	} elsif ($ddslot10 == 7) {
		ddslot1crs10();
	} elsif ($ddslot10 == 8) {
		$ddcolor = "$red"; ddslot1jwl4();
	} elsif ($ddslot10 == 9) {	
		$ddcolor = "$boldwhite"; ddslot1dia4();		
	} elsif ($ddslot10 == 10) {	
		$ddcolor = "$boldwhite"; ddslot1dia4();
	} elsif ($ddslot10 == 11) {
		$ddcolor = "$black"; ddslot1crs4();		
	} else {
		ddslotwhite();
	}

}

sub ddslot11 {
	if ($ddslot11 eq 'spining') {
		ddslotspining();
	} elsif ($ddslot11 == 5) {
		ddslot1emr11();	
	} elsif ($ddslot11 == 8) {
		$ddcolor = "$red"; ddslot1jwl5();
	} elsif ($ddslot11 == 9) {	
		$ddcolor = "$boldwhite"; ddslot1dia5();		
	} elsif ($ddslot11 == 10) {	
		$ddcolor = "$boldwhite"; ddslot1dia5();
	} elsif ($ddslot11 == 11) {
		$ddcolor = "$black"; ddslot1crs5();		
	} else {
		ddslotwhite();
	}

}

sub ddcolorr1 {
	$ddcolor = $ddr1color;
}

sub ddcolorr2 {
	$ddcolor = $ddr2color;
}

sub ddcolorr3 {
	$ddcolor = $ddr3color;
}

sub ddreel1 {
	$ddreel = 1;
	if ($ddreelspin == 3) {
		$ddslot1 = 'spining';
		$ddslot2 = 'spining';
		$ddslot3 = 'spining';
		$ddslot4 = 'spining';
		$ddslot5 = 'spining';
		$ddslot6 = 'spining';
		$ddslot7 = 'spining';
		$ddslot8 = 'spining';
		$ddslot9 = 'spining';
		$ddslot10 = 'spining';
		$ddslot11 = 'spining';
		$ddslot12 = 'spining';
		$ddslot13 = 'spining';
		$ddslot14 = 'spining';
	} else {
		$ddslot1 = $ddsvslot1;
		$ddslot2 = $ddsvslot1;
		$ddslot3 = $ddsvslot1;
		$ddslot4 = $ddsvslot1;
		$ddslot5 = $ddsvslot1;
		$ddslot6 = $ddsvslot1;
		$ddslot7 = $ddsvslot1;
		$ddslot8 = $ddsvslot1;
		$ddslot9 = $ddsvslot1;
		$ddslot10 = $ddsvslot1;
		$ddslot11 = $ddsvslot1;
		$ddslot12 = $ddsvslot1;
		$ddslot13 = $ddsvslot1;
		$ddslot14 = $ddsvslot1;
	}
	
}

sub ddreel2 {
	$ddreel = 2;
	if ($ddreelspin >= 2) {
		$ddslot1 = 'spining';
		$ddslot2 = 'spining';
		$ddslot3 = 'spining';
		$ddslot4 = 'spining';
		$ddslot5 = 'spining';
		$ddslot6 = 'spining';
		$ddslot7 = 'spining';
		$ddslot8 = 'spining';
		$ddslot9 = 'spining';
		$ddslot10 = 'spining';
		$ddslot11 = 'spining';
		$ddslot12 = 'spining';
		$ddslot13 = 'spining';
		$ddslot14 = 'spining';
	} else {
		$ddslot1 = $ddsvslot2;
		$ddslot2 = $ddsvslot2;
		$ddslot3 = $ddsvslot2;
		$ddslot4 = $ddsvslot2;
		$ddslot5 = $ddsvslot2;
		$ddslot6 = $ddsvslot2;
		$ddslot7 = $ddsvslot2;
		$ddslot8 = $ddsvslot2;
		$ddslot9 = $ddsvslot2;
		$ddslot10 = $ddsvslot2;
		$ddslot11 = $ddsvslot2;
		$ddslot12 = $ddsvslot2;
		$ddslot13 = $ddsvslot2;
		$ddslot14 = $ddsvslot2;
	}
}

sub ddreel3 {
	$ddreel = 3;
	if ($ddreelspin >= 1) {
		$ddslot1 = 'spining';
		$ddslot2 = 'spining';
		$ddslot3 = 'spining';
		$ddslot4 = 'spining';
		$ddslot5 = 'spining';
		$ddslot6 = 'spining';
		$ddslot7 = 'spining';
		$ddslot8 = 'spining';
		$ddslot9 = 'spining';
		$ddslot10 = 'spining';
		$ddslot11 = 'spining';
		$ddslot12 = 'spining';
		$ddslot13 = 'spining';
		$ddslot14 = 'spining';
	} else {
		$ddslot1 = $ddsvslot3;
		$ddslot2 = $ddsvslot3;
		$ddslot3 = $ddsvslot3;
		$ddslot4 = $ddsvslot3;
		$ddslot5 = $ddsvslot3;
		$ddslot6 = $ddsvslot3;
		$ddslot7 = $ddsvslot3;
		$ddslot8 = $ddsvslot3;
		$ddslot9 = $ddsvslot3;
		$ddslot10 = $ddsvslot3;
		$ddslot11 = $ddsvslot3;
		$ddslot12 = $ddsvslot3;
		$ddslot13 = $ddsvslot3;
		$ddslot14 = $ddsvslot3;
	}
}

sub ddmid0a {
	print color 'reset';
	print colored('|     []',"$boldblack on_$bgcblack");
	print color 'reset';
}

sub ddmid0 {
	print color 'reset';
	print colored('[]',"$boldblack on_$bgcblack");
	print color 'reset';
}

sub ddmid0b {
	print color 'reset';
	print colored('|',"$boldblack on_$bgcblack");
	print colored(' PAY ',"$boldyellow on_$bgcblack");
	print colored('[]',"$boldblack on_$bgcblack");
	print color 'reset';
}

sub ddmid0c {
	print color 'reset';
	print colored('|',"$boldblack on_$bgcblack");
	print colored('LINE ',"$boldyellow on_$bgcblack");
	print colored('[]',"$boldblack on_$bgcblack");
	print color 'reset';
}

sub ddmid1a {
	print color 'reset';
	print colored('|     ',"$boldblack on_$bgcblack");
	print colored('<>',"$boldblue on_$bgcblue");
	print color 'reset';
}

sub ddmid1 {
	print color 'reset';
	print colored('<>',"$boldblue on_$bgcblue");
	print color 'reset';
}

sub ddslotb {
	print color 'reset';
	print colored('      ',"$boldblack on_$bgcblack");
	print colored('II',"$boldyellow on_$bgcyellow");
	print colored(' ',"$black on_$bgcblack");
	print colored('II',"$boldyellow on_$bgcyellow");
	print colored('      |',"$boldblack on_$bgcblack");
	print color 'reset';
}

sub ddslota {
	print color 'reset';
	print colored('      ',"$boldblack on_$bgcblack");
	print colored('IIIII',"$boldyellow on_$bgcyellow");
	print colored('      |',"$boldblack on_$bgcblack");
	print color 'reset';
}

sub ddaddmoney {
	if ($ddx eq "111") {
		$ddaddmoney = 1000 * $coin;
		$beepnum = 6;
		$ddstwin = $ddstwin + 1;
	} elsif ($ddx eq "222") {
		$ddaddmoney = 500 * $coin;
		$beepnum = 5;
		$ddstwin = $ddstwin + 1;
	} elsif ($ddx eq "333") {
		$ddaddmoney = 150 * $coin;
		$beepnum = 4;
		$ddstwin = $ddstwin + 1;
	} elsif ($ddx eq "444") {
		$ddaddmoney = 80 * $coin;
		$beepnum = 4;
		$ddstwin = $ddstwin + 1;
	} elsif ($ddx eq "555") {
		$ddaddmoney = 45 * $coin;
		$beepnum = 3;
		$ddstwin = $ddstwin + 1;
	} elsif ($ddx eq "666") {
		$ddaddmoney = 22 * $coin;
		$beepnum = 3;
		$ddstwin = $ddstwin + 1;
	} elsif ($ddx eq "777") {
		$ddaddmoney = 15 * $coin;
		$beepnum = 3;
		$ddstwin = $ddstwin + 1;
	} elsif ($ddx eq "121") {
		$ddaddmoney = 700 * $coin;
		$beepnum = 5;
		$ddstwin = $ddstwin + 1;
	} elsif ($ddx eq "212") {
		$ddaddmoney = 300 * $coin;
		$beepnum = 4;
		$ddstwin = $ddstwin + 1;
	} elsif ($ddx eq "141") {
		$ddaddmoney = 180 * $coin;
		$beepnum = 4;
		$ddstwin = $ddstwin + 1;
	} elsif ($ddx eq "252") {
		$ddaddmoney = 110 * $coin;
		$beepnum = 4;
		$ddstwin = $ddstwin + 1;
	} elsif ($ddx eq "454") {
		$ddaddmoney = 60 * $coin;
		$beepnum = 3;
		$ddstwin = $ddstwin + 1;
	} elsif ($ddx eq "545") {
		$ddaddmoney = 35 * $coin;
		$beepnum = 3;
		$ddstwin = $ddstwin + 1;
	} elsif ($ddx eq "464") {
		$ddaddmoney = 30 * $coin;
		$beepnum = 3;
		$ddstwin = $ddstwin + 1;
	} elsif ($ddx eq "646") {
		$ddaddmoney = 18 * $coin;
		$beepnum = 3;
		$ddstwin = $ddstwin + 1;					
	} else {
		$ddaddmoney = 0;
		$beepnum = 0;
		$ddstlose = $ddstlose + 1;
	}	
}
			
sub ddmainscreen {
	ddmid0a(); ddreel1(); ddcolorr1(); sep; ddslot1(); sep; ddmid0(); ddreel2(); ddcolorr2(); sep; ddslot1(); sep; ddmid0(); ddreel3(); ddcolorr3(); sep; ddslot1(); sep; ddmid0(); ddwinnings(); print colored('|',"$boldblack on_$bgcblack"); print"\n";
	ddmid0a(); ddreel1(); ddcolorr1(); sep; ddslot2(); sep; ddmid0(); ddreel2(); ddcolorr2(); sep; ddslot2(); sep; ddmid0(); ddreel3(); ddcolorr3(); sep; ddslot2(); sep; ddmid0(); print colored('                 |',"$boldblack on_$bgcblack"); print"\n";
	ddmid0a(); ddreel1(); ddcolorr1(); sep; ddslot3(); sep; ddmid0(); ddreel2(); ddcolorr2(); sep; ddslot3(); sep; ddmid0(); ddreel3(); ddcolorr3(); sep; ddslot3(); sep; ddmid0(); ddfunds(); print colored('|',"$boldblack on_$bgcblack"); print"\n";
	ddmid0a(); ddreel1(); ddcolorr1(); sep; ddslot4(); sep; ddmid0(); ddreel2(); ddcolorr2(); sep; ddslot4(); sep; ddmid0(); ddreel3(); ddcolorr3(); sep; ddslot4(); sep; ddmid0(); print colored('                 |',"$boldblack on_$bgcblack"); print"\n";
	ddmid0b(); ddreel1(); ddcolorr1(); sep; ddslot5(); sep; ddmid0(); ddreel2(); ddcolorr2(); sep; ddslot5(); sep; ddmid0(); ddreel3(); ddcolorr3(); sep; ddslot5(); sep; ddmid0(); ddslota(); print"\n";
	ddmid1a(); ddreel1(); ddcolorr1(); sep; ddslot6(); sep; ddmid1(); ddreel2(); ddcolorr2(); sep; ddslot6(); sep; ddmid1(); ddreel3(); ddcolorr3(); sep; ddslot6(); sep; ddmid1(); ddslotb(); print"\n";
	ddmid0c(); ddreel1(); ddcolorr1(); sep; ddslot7(); sep; ddmid0(); ddreel2(); ddcolorr2(); sep; ddslot7(); sep; ddmid0(); ddreel3(); ddcolorr3(); sep; ddslot7(); sep; ddmid0(); ddslotb(); print"\n";
	ddmid0a(); ddreel1(); ddcolorr1(); sep; ddslot8(); sep; ddmid0(); ddreel2(); ddcolorr2(); sep; ddslot8(); sep; ddmid0(); ddreel3(); ddcolorr3(); sep; ddslot8(); sep; ddmid0(); ddslotb(); beepalrm();
	ddmid0a(); ddreel1(); ddcolorr1(); sep; ddslot9(); sep; ddmid0(); ddreel2(); ddcolorr2(); sep; ddslot9(); sep; ddmid0(); ddreel3(); ddcolorr3(); sep; ddslot9(); sep; ddmid0(); ddslotb(); beepalrm();
	ddmid0a(); ddreel1(); ddcolorr1(); sep; ddslot10(); sep; ddmid0(); ddreel2(); ddcolorr2(); sep; ddslot10(); sep; ddmid0(); ddreel3(); ddcolorr3(); sep; ddslot10(); sep; ddmid0(); ddslota(); beepalrm();
	ddmid0a(); ddreel1(); ddcolorr1(); sep; ddslot11(); sep; ddmid0(); ddreel2(); ddcolorr2(); sep; ddslot11(); sep; ddmid0(); ddreel3(); ddcolorr3(); sep; ddslot11(); sep; ddmid0(); print colored('                 |',"$boldblack on_$bgcblack"); beepalrm();
	print colored('|     [][][][][][][][][][][][][][][][][][][][][][][][][][][][]   INSERT TOKEN  |',"$boldblack on_$bgcblack");  beepalrm();
	print colored('|------------------------------------------------------------------------------|',"$boldblack on_$bgcblack");  beepalrm();
	print colored('|',"$boldblack on_$bgcblack");  
	print colored('                              DOUBLE BLUE DIAMOND                             ',"$blue on_$bgcgreen"); 
	print colored('|',"$boldblack on_$bgcblack");  beepalrm();
	print colored('\------------------------------------------------------------------------------/',"$boldblack on_$bgcblack");  beepalrm();	
	
	$beepnum = 0;
}

sub ddwinnings {
	print colored(' WINNINGS ',"$boldblack on_$bgcblack");
	
	sep;
	if ($ddaddmoney > 9999999) {
	print colored(sprintf("%.1e", $ddaddmoney),"$boldred on_$bgcred");
	} elsif ($ddaddmoney >= 1000000) {
	print colored("$ddaddmoney","$boldred on_$bgcred");
	} elsif ($ddaddmoney >= 100000) {
	print colored(" $ddaddmoney","$boldred on_$bgcred");
	} elsif ($ddaddmoney >= 10000) {
	print colored("  $ddaddmoney","$boldred on_$bgcred");
	} elsif ($ddaddmoney >= 1000) {
	print colored("   $ddaddmoney","$boldred on_$bgcred");
	} elsif ($ddaddmoney >= 100) {
	print colored("    $ddaddmoney","$boldred on_$bgcred");
	} elsif ($ddaddmoney >= 10) {
	print colored("     $ddaddmoney","$boldred on_$bgcred");
	} elsif ($ddaddmoney >= 1) {
	print colored("      $ddaddmoney","$boldred on_$bgcred");
	} else {
	print colored("      $ddaddmoney","$boldred on_$bgcred");
	}
	sep;
}

sub ddfunds {
	print colored(' FUNDS ',"$boldblack on_$bgcblack");
	
	sep;
	if ($money > 9999999999) {
	print colored(sprintf("%.4e", $money),"$boldgreen on_$bgcgreen");
	} elsif ($money >= 1000000000) {
	print colored("$money","$boldgreen on_$bgcgreen");
	} elsif ($money >= 100000000) {
	print colored(" $money","$boldgreen on_$bgcgreen");
	} elsif ($money >= 10000000) {
	print colored("  $money","$boldgreen on_$bgcgreen");
	} elsif ($money >= 1000000) {
	print colored("   $money","$boldgreen on_$bgcgreen");
	} elsif ($money >= 100000) {
	print colored("    $money","$boldgreen on_$bgcgreen");
	} elsif ($money >= 10000) {
	print colored("     $money","$boldgreen on_$bgcgreen");
	} elsif ($money >= 1000) {
	print colored("      $money","$boldgreen on_$bgcgreen");
	} elsif ($money >= 100) {
	print colored("       $money","$boldgreen on_$bgcgreen");
	} elsif ($money >= 10) {
	print colored("        $money","$boldgreen on_$bgcgreen");
	} elsif ($money >= 1) {
	print colored("         $money","$boldgreen on_$bgcgreen");
	} else {
	print colored("         $money","$boldgreen on_$bgcgreen");
	}
	sep;
}

sub ddtopend {
	print colored('                ',"$white on_$bgcgreen");
	print colored('|',"$boldblack on_$bgcblack");
}

sub ddtopprint {
	print colored('/------------------------------------------------------------------------------\\',"$boldblack on_$bgcblack");  print"\n";
	print colored('|',"$boldblack on_$bgcblack");  
	print colored('                              DOUBLE BLUE DIAMOND                             ',"$blue on_$bgcgreen"); 
	print colored('|',"$boldblack on_$bgcblack"); print"\n";
	print colored('|',"$boldblack on_$bgcblack");
	print colored('   ___ ',"$boldblue on_$bgcgreen");  print colored(' x3 = 1000',"$white on_$bgcgreen"); 
	print colored(' ___ ',"$boldwhite on_$bgcgreen"); print colored(' x3 = 150 ',"$white on_$bgcgreen"); 
	print colored(' /|\\ ',"$boldgreen on_$bgcgreen"); print colored(' x3 = 45  ',"$white on_$bgcgreen"); 
	print colored(' /|\\ ',"$boldblack on_$bgcgreen"); print colored(' x3 = 15  ',"$white on_$bgcgreen"); 
	print colored(' RB',"$red on_$bgcwhite"); 
	print colored(' EM',"$boldgreen on_$bgcwhite");
	print colored(' RB',"$red on_$bgcwhite");
	print colored(' = 60  ',"$boldblack on_$bgcwhite");
	print colored('|',"$boldblack on_$bgcblack");
	print"\n";

	print colored('|',"$boldblack on_$bgcblack");
	print colored(' _/_|_\\',"$boldblue on_$bgcgreen"); print colored('          ',"$white on_$bgcgreen");  
	print colored('/_|_\\',"$boldwhite on_$bgcgreen"); print colored('          ',"$white on_$bgcgreen"); 
	print colored('// \\\\',"$boldgreen on_$bgcgreen"); print colored('          ',"$white on_$bgcgreen"); 
	print colored(' ||| ',"$boldblack on_$bgcgreen"); print colored('          ',"$white on_$bgcgreen"); 
	print colored(' EM',"$boldgreen on_$bgcwhite"); 
	print colored(' RB',"$red on_$bgcwhite");
	print colored(' EM',"$boldgreen on_$bgcwhite");
	print colored(' = 35  ',"$boldblack on_$bgcwhite");
	print colored('|',"$boldblack on_$bgcblack");
	print"\n";

	print colored('|',"$boldblack on_$bgcblack");
	print colored('/_|_\\',"$boldblue on_$bgcgreen"); print colored(' /',"$blue on_$bgcgreen"); print colored('          ',"$white on_$bgcgreen");  
	print colored('\\ | /',"$boldwhite on_$bgcgreen"); print colored('          ',"$white on_$bgcgreen"); 
	print colored('\\\\ //',"$boldgreen on_$bgcgreen"); print colored('          ',"$white on_$bgcgreen");
	print colored(' \\|/ ',"$boldblack on_$bgcgreen"); print colored('          ',"$white on_$bgcgreen"); 
	print colored(' RB',"$red on_$bgcwhite"); 
	print colored(' TZ',"$boldyellow on_$bgcwhite");
	print colored(' RB',"$red on_$bgcwhite");
	print colored(' = 30  ',"$boldblack on_$bgcwhite");
	print colored('|',"$boldblack on_$bgcblack");
	print"\n";

	print colored('|',"$boldblack on_$bgcblack");
	print colored('\\ ',"$boldblue on_$bgcgreen"); print colored('| // ',"$blue on_$bgcgreen"); print colored('          ',"$white on_$bgcgreen");  
	print colored(' \\|/ ',"$boldwhite on_$bgcgreen");  print colored('          ',"$white on_$bgcgreen"); 
	print colored(' \\|/ ',"$boldgreen on_$bgcgreen"); print colored('                         ',"$white on_$bgcgreen"); 
	print colored(' TZ',"$boldyellow on_$bgcwhite");
	print colored(' RB',"$red on_$bgcwhite");
	print colored(' TZ',"$boldyellow on_$bgcwhite");
	print colored(' = 18  ',"$boldblack on_$bgcwhite");
	print colored('|',"$boldblack on_$bgcblack"); 
	print"\n";

	print colored('|',"$boldblack on_$bgcblack");
	print colored(' \\',"$boldblue on_$bgcgreen"); print colored('|/   ',"$blue on_$bgcgreen");  print colored('          ',"$white on_$bgcgreen"); print colored('          ',"$white on_$bgcgreen");  
	print colored('                    ',"$white on_$bgcgreen"); 
	print colored('                               |',"$boldblack on_$bgcblack");
	print"\n";

	print colored('|',"$boldblack on_$bgcblack");
	print colored('   ___ ',"$boldwhite on_$bgcgreen");  print colored(' x3 = 500',"$white on_$bgcgreen");  
	print colored('  ___ ',"$red on_$bgcgreen"); print colored(' x3 = 80  ',"$white on_$bgcgreen"); 
	print colored(' ___ ',"$boldyellow on_$bgcgreen"); print colored(' x3 = 22  ',"$white on_$bgcgreen"); 
	print colored('  DD',"$boldblue on_$bgcblack"); 
	print colored(' DD',"$boldwhite on_$bgcblack");
	print colored(' DD',"$boldblue on_$bgcblack");
	print colored(' = 700 ',"$white on_$bgcblack");
	print colored('              |',"$boldblack on_$bgcblack");
	print"\n"; 

	print colored('|',"$boldblack on_$bgcblack");
	print colored(' _/_|_\\',"$boldwhite on_$bgcgreen"); print colored('          ',"$white on_$bgcgreen"); 
	print colored('/\_/\\',"$red on_$bgcgreen"); print colored('          ',"$white on_$bgcgreen");
	print colored('|\_/|',"$boldyellow on_$bgcgreen"); print colored('          ',"$white on_$bgcgreen"); 
	print colored('  DD',"$boldwhite on_$bgcblack"); 
	print colored(' DD',"$boldblue on_$bgcblack");
	print colored(' DD',"$boldwhite on_$bgcblack");
	print colored(' = 300 ',"$white on_$bgcblack");
	print colored('              |',"$boldblack on_$bgcblack"); 
	print"\n"; 

	print colored('|',"$boldblack on_$bgcblack");
	print colored('/_|_\ /',"$boldwhite on_$bgcgreen"); print colored('          ',"$white on_$bgcgreen");  
	print colored('||_||',"$red on_$bgcgreen"); print colored('          ',"$white on_$bgcgreen"); 
	print colored('||_||          ',"$boldyellow on_$bgcgreen"); 
	print colored('  DD',"$boldblue on_$bgcblack"); 
	print colored(' RB',"$red on_$bgcblack");
	print colored(' DD',"$boldblue on_$bgcblack");
	print colored(' = 180 ',"$white on_$bgcblack");
	print colored('              |',"$boldblack on_$bgcblack");
	print"\n";

	print colored('|',"$boldblack on_$bgcblack");
	print colored('\ | // ',"$boldwhite on_$bgcgreen"); print colored('          ',"$white on_$bgcgreen");  
	print colored('\/_\/',"$red on_$bgcgreen"); print colored('          ',"$white on_$bgcgreen");
	print colored('|/_\|          ',"$boldyellow on_$bgcgreen"); 
	print colored('  DD',"$boldwhite on_$bgcblack"); 
	print colored(' EM',"$boldgreen on_$bgcblack");
	print colored(' DD',"$boldwhite on_$bgcblack");
	print colored(' = 110 ',"$white on_$bgcblack");
	print colored('              |',"$boldblack on_$bgcblack");
	print"\n"; 

	print colored('|',"$boldblack on_$bgcblack");
	print colored(' \|/   ',"$boldwhite on_$bgcgreen");  
	print colored('     P = Play   C = Return To Casino Men',"$boldgreen on_$bgcgreen");
	print colored('u   EXIT = Quit                |',"$boldblack on_$bgcblack"); print"\n"; 

	print colored('|------------------------------------------------------------------------------|',"$boldblack on_$bgcblack");  print"\n";
	print colored('|     [][][][][][][][][][][][][][][][][][][][][][][][][][][][]    GPC-SLOTS 2  |',"$boldblack on_$bgcblack");  print"\n";

}

################################################################################################################################
## GENRE: Slot Mahine
## NAME: High Roller Sevens
## AUTHOR: MikeeUSA

sub ssmain {
	ssresetvars();
	$ssaddmoney1 = 0;
	sslights();
	ssspinreel();
	ssreeltrans();
	
	if ($animate == 1) {
		$ssreelspin = 3;
		ssmainscreen();
		ssdisplaywin();
		medpause();
		newlines();
	
		$ssreelspin = 2;
		ssmainscreen();
		ssdisplaywin();
		smallpause();
		newlines();
		
		$ssreelspin = 1;
		ssmainscreen();
		ssdisplaywin();
		smallpause();
		newlines();
	}	
	$ssx1 = $sssvslot1.$sssvslot2.$sssvslot3;
	$ssx2 = $sssvslot1a.$sssvslot2a.$sssvslot3a;
	$ssx3 = $sssvslot1b.$sssvslot2b.$sssvslot3b;
	$ssx4 = $sssvslot1a.$sssvslot2.$sssvslot3b;
	$ssx5 = $sssvslot1b.$sssvslot2.$sssvslot3a;
	ssaddmoney();
	sscalcfunds();
	$ssreelspin = 0;
	ssmainscreen();
	ssdisplaywin();
	ptracker();
	ssstartinfo();
}

sub ssmain2 {
	ssresetvars();
	$ssaddmoney1 = 0;
	$sslines = 1;
	sslights();
	ssreeltrans();
	ssmainscreen();
	$ssx1 = 'null';
	$ssx2 = 'null';
	$ssx3 = 'null';
	$ssx4 = 'null';
	$ssx5 = 'null';
	$ssaddmoney = 0;
	ssdisplaywin();
	ssstartinfo();
}

sub ssresetvars {
	$ssreelspin = 0;
}

sub ssaddmoney {
	$ssaddmoney1 = 0;
	$ssaddmoney2 = 0;
	$ssaddmoney3 = 0;
	$ssaddmoney4 = 0;
	$ssaddmoney5 = 0;
	if ($sslines == 3) {
		ssaddmoney1();
		ssaddmoney2();
		ssaddmoney3();
		ssaddmoney4();
		ssaddmoney5();		
	} elsif ($sslines == 2) {
		ssaddmoney1();
		ssaddmoney2();	
	} elsif ($sslines == 1) {
		ssaddmoney1();	
	} else {
	}
	$ssaddmoney = $ssaddmoney1 + $ssaddmoney2 + $ssaddmoney3 + $ssaddmoney4 + $ssaddmoney5;
}


sub ssaddmoney1 {
	if (($ssmisalign1 == 1) or ($ssmisalign2 == 1) or ($ssmisalign3 == 1)) {
		$ssaddmoney1 = 0;
		$ssstlose = $ssstlose + 1;
	} elsif ($ssx1 eq "111") {
		if ($sslines == 3) {
			if (($coin * 500000) >= (($projkpot)*(0.50))) {
				$ssaddmoney1 = $projkpot + (500000 * $coin);
				#This is so winning the jackpot is always a big windfall
			} else {
				$ssaddmoney1 = $projkpot;
			}
		$projkpot = $projkpot2;
		$beepnum = 8;
		} else {
		$ssaddmoney1 = 500000 * $coin;
		$beepnum = 7;
		}
		$ssstwin = $ssstwin + 1;
	} elsif ($ssx1 eq "121") {
		$ssaddmoney1 = 12000 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 6;	
	} elsif ($ssx1 eq "222") {
		$ssaddmoney1 = 10000 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 6;
	} elsif ($ssx1 eq "212") {
		$ssaddmoney1 = 8000 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 6;		
	} elsif ($ssx1 eq "333") {
		$ssaddmoney1 = 6000 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 5;
	} elsif ($ssx1 eq "434") {
		$ssaddmoney1 = 4000 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 5;
	} elsif ($ssx1 eq "444") {
		$ssaddmoney1 = 2000 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 5;
	} elsif ($ssx1 eq "555") {
		$ssaddmoney1 = 700 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 4;
	} elsif ($ssx1 eq "666") {
		$ssaddmoney1 = 400 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 4;
	} elsif ($ssx1 eq "777") {
		$ssaddmoney1 = 250 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 4;	
	} elsif ($ssx1 eq "888") {
		$ssaddmoney1 = 130 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 4;
	} elsif ($ssx1 eq "999") {
		$ssaddmoney1 = 80 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 3;
	} elsif ($ssx1 eq "101010") {
		$ssaddmoney1 = 20 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 3;
	} else {
		$ssaddmoney1 = 0;
		$ssstlose = $ssstlose + 1;
	}	
}

sub ssaddmoney2 {
	if (($ssmisalign1 == 1) or ($ssmisalign2 == 1) or ($ssmisalign3 == 1)) {
		$ssaddmoney2 = 0;
	} elsif ($ssx2 eq "111") {
		$ssaddmoney2 = 500000 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 7;
	} elsif ($ssx2 eq "121") {
		$ssaddmoney2 = 12000 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 6;
	} elsif ($ssx2 eq "222") {
		$ssaddmoney2 = 10000 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 6;
	} elsif ($ssx2 eq "212") {
		$ssaddmoney2 = 8000 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 6;
	} elsif ($ssx2 eq "333") {
		$ssaddmoney2 = 6000 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 5;
	} elsif ($ssx2 eq "434") {
		$ssaddmoney2 = 4000 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 5;
	} elsif ($ssx2 eq "444") {
		$ssaddmoney2 = 2000 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 5;
	} elsif ($ssx2 eq "555") {
		$ssaddmoney2 = 700 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 4;
	} elsif ($ssx2 eq "666") {
		$ssaddmoney2 = 400 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 4;
	} elsif ($ssx2 eq "777") {
		$ssaddmoney2 = 250 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 4;	
	} elsif ($ssx2 eq "888") {
		$ssaddmoney2 = 130 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 4;
	} elsif ($ssx2 eq "999") {
		$ssaddmoney2 = 80 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 3;
	} elsif ($ssx2 eq "101010") {
		$ssaddmoney2 = 20 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 3;
	} else {
		$ssaddmoney2 = 0;
		$ssstlose = $ssstlose + 1;
	}	
}

sub ssaddmoney3 {
	if (($ssmisalign1 == 1) or ($ssmisalign2 == 1) or ($ssmisalign3 == 1)) {
		$ssaddmoney3 = 0;
	} elsif ($ssx3 eq "111") {
		$ssaddmoney3 = 500000 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 7;
	} elsif ($ssx3 eq "121") {
		$ssaddmoney3 = 12000 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 6;
	} elsif ($ssx3 eq "222") {
		$ssaddmoney3 = 10000 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 6;
	} elsif ($ssx3 eq "212") {
		$ssaddmoney3 = 8000 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 6;
	} elsif ($ssx3 eq "333") {
		$ssaddmoney3 = 6000 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 5;
	} elsif ($ssx3 eq "434") {
		$ssaddmoney3 = 4000 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 5;
	} elsif ($ssx3 eq "444") {
		$ssaddmoney3 = 2000 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 5;
	} elsif ($ssx3 eq "555") {
		$ssaddmoney3 = 700 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 4;
	} elsif ($ssx3 eq "666") {
		$ssaddmoney3 = 400 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 4;
	} elsif ($ssx3 eq "777") {
		$ssaddmoney3 = 250 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 4;	
	} elsif ($ssx3 eq "888") {
		$ssaddmoney3 = 130 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 4;
	} elsif ($ssx3 eq "999") {
		$ssaddmoney3 = 80 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 3;
	} elsif ($ssx3 eq "101010") {
		$ssaddmoney3 = 20 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 3;
	} else {
		$ssaddmoney3 = 0;
		$ssstlose = $ssstlose + 1;
	}	
}

sub ssaddmoney4 {
	if (($ssmisalign1 == 1) or ($ssmisalign2 == 1) or ($ssmisalign3 == 1)) {
		$ssaddmoney4 = 0;
	} elsif ($ssx4 eq "111") {
		$ssaddmoney4 = 500000 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 7;
	} elsif ($ssx4 eq "121") {
		$ssaddmoney4 = 12000 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 6;
	} elsif ($ssx4 eq "222") {
		$ssaddmoney4 = 10000 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 6;
	} elsif ($ssx4 eq "212") {
		$ssaddmoney4 = 8000 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 6;
	} elsif ($ssx4 eq "333") {
		$ssaddmoney4 = 6000 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 5;
	} elsif ($ssx4 eq "434") {
		$ssaddmoney4 = 4000 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 5;
	} elsif ($ssx4 eq "444") {
		$ssaddmoney4 = 2000 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 5;
	} elsif ($ssx4 eq "555") {
		$ssaddmoney4 = 700 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 4;
	} elsif ($ssx4 eq "666") {
		$ssaddmoney4 = 400 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 4;
	} elsif ($ssx4 eq "777") {
		$ssaddmoney4 = 250 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 4;	
	} elsif ($ssx4 eq "888") {
		$ssaddmoney4 = 130 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 4;
	} elsif ($ssx4 eq "999") {
		$ssaddmoney4 = 80 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 3;
	} elsif ($ssx4 eq "101010") {
		$ssaddmoney4 = 20 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 3;
	} else {
		$ssaddmoney4 = 0;
		$ssstlose = $ssstlose + 1;
	}	
}

sub ssaddmoney5 {
	if (($ssmisalign1 == 1) or ($ssmisalign2 == 1) or ($ssmisalign3 == 1)) {
		$ssaddmoney5 = 0;
	} elsif ($ssx5 eq "111") {
		$ssaddmoney5 = 500000 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 7;
	} elsif ($ssx5 eq "121") {
		$ssaddmoney5 = 12000 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 6;
	} elsif ($ssx5 eq "222") {
		$ssaddmoney5 = 10000 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 6;
	} elsif ($ssx5 eq "212") {
		$ssaddmoney5 = 8000 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 6;
	} elsif ($ssx5 eq "333") {
		$ssaddmoney5 = 6000 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 5;
	} elsif ($ssx5 eq "434") {
		$ssaddmoney5 = 4000 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 5;
	} elsif ($ssx5 eq "444") {
		$ssaddmoney5 = 2000 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 5;
	} elsif ($ssx5 eq "555") {
		$ssaddmoney5 = 700 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 4;
	} elsif ($ssx5 eq "666") {
		$ssaddmoney5 = 400 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 4;
	} elsif ($ssx5 eq "777") {
		$ssaddmoney5 = 250 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 4;		
	} elsif ($ssx5 eq "888") {
		$ssaddmoney5 = 130 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 4;
	} elsif ($ssx5 eq "999") {
		$ssaddmoney5 = 80 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 3;
	} elsif ($ssx5 eq "101010") {
		$ssaddmoney5 = 20 * $coin;
		$ssstwin = $ssstwin + 1;
		$beepnum = 3;
	} else {
		$ssaddmoney5 = 0;
		$ssstlose = $ssstlose + 1;
	}	
}

sub sscalcfunds {
$money = $money + $ssaddmoney;
$ssstmc = $ssstmc + $ssaddmoney;
}

sub sslights {
	if ($sslines == 1) {
	$sspx2 = "$boldgreen";
	$sspx3 = "$boldgreen";
	} elsif ($sslines == 2) {
	$sspx2 = "$boldyellow";
	$sspx3 = "$boldgreen";
	} elsif ($sslines == 3) {
	$sspx2 = "$boldyellow";
	$sspx3 = "$boldyellow";
	} else {
	$sspx2 = "$boldgreen";
	$sspx3 = "$boldgreen";
	}
}

sub ssstartinfo {
	tokeneval();
	$ssstartinfo = <STDIN>;
	chomp($ssstartinfo);

	if (($ssstartinfo eq 'a') or ($ssstartinfo eq 'A')) {
		$ssstartinfo = $ssagaincmd;
	} elsif (($ssstartinfo eq 'p') or ($ssstartinfo eq 'P') or ($ssstartinfo eq '1p') or ($ssstartinfo eq '1P')
		or ($ssstartinfo eq '2p') or ($ssstartinfo eq '2P') or ($ssstartinfo eq '3p') or ($ssstartinfo eq '3P')) {
		$ssagaincmd = $ssstartinfo;
	} else {
		#Do Nothing		
	}

	if (($ssstartinfo eq 'p') or ($ssstartinfo eq 'P') or ($ssstartinfo eq '1p') or ($ssstartinfo eq '1P')) {
		if ($money >= (5 * $coin)) {
			$money = $money - (5 * $coin);
			$moneyexp = $moneyexp + (5 * $coin);
			$ssstmc2 = $ssstmc2 + (5 * $coin);
			$spins = $spins + 1;
			$ssstspins = $ssstspins + 1;
			$sslines = 1;
			$projkpot = $projkpot + (2 * $coin);
			newlines();
			ssmain();
		} else {
			newlines();
			ssmain2();
					
		}
	} elsif (($ssstartinfo eq '2p') or ($ssstartinfo eq '2P')) {
		if ($money >= (10 * $coin)) {
			$money = $money - (10 * $coin);
			$moneyexp = $moneyexp + (10 * $coin);
			$ssstmc2 = $ssstmc2 + (10 * $coin);
			$spins = $spins + 1;
			$ssstspins = $ssstspins + 1;
			$sslines = 2;
			$projkpot = $projkpot + (7 * $coin);
			newlines();
			ssmain();
		} else {
			newlines();
			ssmain2();		
		}	
	} elsif (($ssstartinfo eq '3p') or ($ssstartinfo eq '3P')) {
		if ($money >= (15 * $coin)) {
			$money = $money - (15 * $coin);
			$moneyexp = $moneyexp + (15 * $coin);
			$ssstmc2 = $ssstmc2 + (15 * $coin);
			$spins = $spins + 1;
			$ssstspins = $ssstspins + 1;
			$sslines = 3;
			$projkpot = $projkpot + (11 * $coin);
			newlines();
			ssmain();
		} else {
			newlines();
			ssmain2();		
		}		
	} elsif (($ssstartinfo eq 'exit') or ($ssstartinfo eq 'EXIT') or ($ssstartinfo eq 'quit') or ($ssstartinfo eq 'QUIT')) {
		exitgame();
	} elsif (($ssstartinfo eq 'c') or ($ssstartinfo eq 'C'))  {
		print "\n";
		return;
	} else {
		newlines();
		ssmain2();
	}

}

sub sssymseven1  { if ($esegpenguinhrs != 1) { print colored(' 7777777777777777 ',"$sscolor1 on_$bgcblack"); } else { print colored('      lINUx       ',"$sscolor1 on_$bgcblack"); } }
sub sssymseven2  { if ($esegpenguinhrs != 1) { print colored(' 7777777777777777 ',"$sscolor2 on_$bgcblack"); } else { print colored('     L',"$sscolor1 on_$bgcblack"); print colored('  ',"bold $sscolor1 on_$bgcwhite"); print colored('U',"$sscolor1 on_$bgcblack"); print colored('  ',"bold $sscolor1 on_$bgcwhite"); print colored('I      ',"$sscolor1 on_$bgcblack"); } }
sub sssymseven3  { if ($esegpenguinhrs != 1) { print colored(' 7777      777777 ',"$sscolor1 on_$bgcblack"); } else { print colored('     N',"$sscolor1 on_$bgcblack"); print colored('0 ',"$boldblack on_$bgcwhite"); print colored('L',"$sscolor1 on_$bgcblack"); print colored('0 ',"$boldblack on_$bgcwhite"); print colored('U      ',"$sscolor1 on_$bgcblack"); } }
sub sssymseven4  { if ($esegpenguinhrs != 1) { print colored('          777777  ',"$sscolor2 on_$bgcblack"); } else { print colored('     X-----L      ',"$sscolor1 on_$bgcblack"); } }
sub sssymseven5  { if ($esegpenguinhrs != 1) { print colored('         777777   ',"$sscolor1 on_$bgcblack"); } else { print colored('     IN   IN      ',"$sscolor1 on_$bgcblack"); } }
sub sssymseven6  { if ($esegpenguinhrs != 1) { print colored('        777777    ',"$sscolor2 on_$bgcblack"); } else { print colored('     UXLINUX      ',"$sscolor1 on_$bgcblack"); } }
sub sssymseven7  { if ($esegpenguinhrs != 1) { print colored('       777777     ',"$sscolor1 on_$bgcblack"); } else { print colored('    lINUXLINu     ',"$sscolor1 on_$bgcblack"); } }
sub sssymseven8  { if ($esegpenguinhrs != 1) { print colored('      7777777     ',"$sscolor2 on_$bgcblack"); } else { print colored('   uXLINUXLINu    ',"$sscolor1 on_$bgcblack"); } }
sub sssymseven9  { if ($esegpenguinhrs != 1) { print colored('     77777777     ',"$sscolor1 on_$bgcblack"); } else { print colored('   XLINUXLINUX    ',"$sscolor1 on_$bgcblack"); } }
sub sssymseven10 { if ($esegpenguinhrs != 1) { print colored('    777777777     ',"$sscolor2 on_$bgcblack"); } else { print colored('   LINUXLINUXL    ',"$sscolor1 on_$bgcblack"); } }
sub sssymseven11 { if ($esegpenguinhrs != 1) { print colored('    777777777     ',"$sscolor1 on_$bgcblack"); } else { print colored('  /  XLINUXL  \   ',"$sscolor1 on_$bgcblack"); } }   
sub sssymseven12 { if ($esegpenguinhrs != 1) { print colored('    7777777777    ',"$sscolor2 on_$bgcblack"); } else { print colored('  \   UXLIN   /   ',"$sscolor1 on_$bgcblack"); } } 
sub sssymseven13 { if ($esegpenguinhrs != 1) { print colored('     7777777777   ',"$sscolor1 on_$bgcblack"); } else { print colored('   \___INU___/    ',"$sscolor1 on_$bgcblack"); } }

sub sssymseven1a  { if ($esegpenguinhrs != 1) { print colored(' **************** ',"$sscolor1 on_$bgcblack"); } else { print colored('      *****       ',"$sscolor1 on_$bgcblack"); } }
sub sssymseven2a  { if ($esegpenguinhrs != 1) { print colored(' **************** ',"$sscolor2 on_$bgcblack"); } else { print colored('     *',"$sscolor2 on_$bgcblack"); print colored('  ',"$white on_$bgcwhite"); print colored('*',"$sscolor2 on_$bgcblack"); print colored('  ',"$white on_$bgcwhite"); print colored('*      ',"$sscolor2 on_$bgcblack"); } }
sub sssymseven3a  { if ($esegpenguinhrs != 1) { print colored(' ****      ****** ',"$sscolor1 on_$bgcblack"); } else { print colored('     *',"$sscolor1 on_$bgcblack"); print colored(' $',"$boldyellow on_$bgcwhite"); print colored('*',"$sscolor1 on_$bgcblack"); print colored(' $',"$boldyellow on_$bgcwhite"); print colored('*      ',"$sscolor1 on_$bgcblack"); } }
sub sssymseven4a  { if ($esegpenguinhrs != 1) { print colored('          ******  ',"$sscolor2 on_$bgcblack"); } else { print colored('     *-----*      ',"$sscolor2 on_$bgcblack"); } }
sub sssymseven5a  { if ($esegpenguinhrs != 1) { print colored('         ******   ',"$sscolor1 on_$bgcblack"); } else { print colored('     **   **      ',"$sscolor1 on_$bgcblack"); } }
sub sssymseven6a  { if ($esegpenguinhrs != 1) { print colored('        ******    ',"$sscolor2 on_$bgcblack"); } else { print colored('     *******      ',"$sscolor2 on_$bgcblack"); } }
sub sssymseven7a  { if ($esegpenguinhrs != 1) { print colored('       ******     ',"$sscolor1 on_$bgcblack"); } else { print colored('    *********     ',"$sscolor1 on_$bgcblack"); } }
sub sssymseven8a  { if ($esegpenguinhrs != 1) { print colored('      ******      ',"$sscolor2 on_$bgcblack"); } else { print colored('   ***********    ',"$sscolor2 on_$bgcblack"); } }
sub sssymseven9a  { if ($esegpenguinhrs != 1) { print colored('     ******       ',"$sscolor1 on_$bgcblack"); } else { print colored('   ***********    ',"$sscolor1 on_$bgcblack"); } }
sub sssymseven10a { if ($esegpenguinhrs != 1) { print colored('    ******        ',"$sscolor2 on_$bgcblack"); } else { print colored('   ***********    ',"$sscolor2 on_$bgcblack"); } }
sub sssymseven11a { if ($esegpenguinhrs != 1) { print colored('   ******         ',"$sscolor1 on_$bgcblack"); } else { print colored('  /--*******--\   ',"$sscolor1 on_$bgcblack"); } }   
sub sssymseven12a { if ($esegpenguinhrs != 1) { print colored('  ******          ',"$sscolor2 on_$bgcblack"); } else { print colored('  \---*****---/   ',"$sscolor2 on_$bgcblack"); } } 
sub sssymseven13a { if ($esegpenguinhrs != 1) { print colored(' ******           ',"$sscolor1 on_$bgcblack"); } else { print colored('   \___***___/    ',"$sscolor1 on_$bgcblack"); } }                  

sub sssymseven1b  { if ($esegpenguinhrs != 1) { print colored('   777777777      ',"$sscolor2 on_$bgcblack"); } else { print colored('   /~~~INU~~~\    ',"$sscolor2 on_$bgcblack"); } }
sub sssymseven2b  { if ($esegpenguinhrs != 1) { print colored('    77777777',"$sscolor1 on_$bgcblack"); print colored('K     ',"bold $sscolor2 on_$bgcblack"); } else { print colored('  /   UXLIN   \   ',"$sscolor1 on_$bgcblack"); } }
sub sssymseven3b  { if ($esegpenguinhrs != 1) { print colored('     777777',"$sscolor2 on_$bgcblack"); print colored('N',"bold $sscolor1 on_$bgcblack"); print colored('7     ',"$sscolor2 on_$bgcblack"); } else { print colored('  \  XLINUXL  /   ',"$sscolor2 on_$bgcblack"); } }
sub sssymseven4b  { if ($esegpenguinhrs != 1) { print colored('     77777',"$sscolor1 on_$bgcblack"); print colored('A',"bold $sscolor2 on_$bgcblack"); print colored('77     ',"$sscolor1 on_$bgcblack"); } else { print colored('   LINUXLINUXL    ',"$sscolor1 on_$bgcblack"); } }
sub sssymseven5b  { if ($esegpenguinhrs != 1) { print colored('     7777',"$sscolor2 on_$bgcblack"); print colored('L',"bold $sscolor1 on_$bgcblack"); print colored('777     ',"$sscolor2 on_$bgcblack"); } else { print colored('   XLINUXLINUX    ',"$sscolor2 on_$bgcblack"); } }
sub sssymseven6b  { if ($esegpenguinhrs != 1) { print colored('     777',"$sscolor1 on_$bgcblack"); print colored('B',"bold $sscolor2 on_$bgcblack"); print colored('777      ',"$sscolor1 on_$bgcblack"); } else { print colored('   uXLINUXLINu    ',"$sscolor1 on_$bgcblack"); } }
sub sssymseven7b  { if ($esegpenguinhrs != 1) { print colored('     77',"$sscolor2 on_$bgcblack"); print colored('/',"bold $sscolor1 on_$bgcblack"); print colored('777       ',"$sscolor2 on_$bgcblack"); } else { print colored('    lINUXLINu     ',"$sscolor2 on_$bgcblack"); } }
sub sssymseven8b  { if ($esegpenguinhrs != 1) { print colored('    77',"$sscolor1 on_$bgcblack"); print colored('/',"bold $sscolor2 on_$bgcblack"); print colored('777        ',"$sscolor1 on_$bgcblack"); } else { print colored('     UXLINUX      ',"$sscolor1 on_$bgcblack"); } }
sub sssymseven9b  { if ($esegpenguinhrs != 1) { print colored('   77',"$sscolor2 on_$bgcblack"); print colored('K',"bold $sscolor1 on_$bgcblack"); print colored('777         ',"$sscolor2 on_$bgcblack"); } else { print colored('     IN   IN      ',"$sscolor2 on_$bgcblack"); } }
sub sssymseven10b { if ($esegpenguinhrs != 1) { print colored('  77',"$sscolor1 on_$bgcblack"); print colored('N',"bold $sscolor2 on_$bgcblack"); print colored('777          ',"$sscolor1 on_$bgcblack"); } else { print colored('     X-----L      ',"$sscolor1 on_$bgcblack"); } }
sub sssymseven11b { if ($esegpenguinhrs != 1) { print colored(' 77',"$sscolor2 on_$bgcblack"); print colored('A',"bold $sscolor1 on_$bgcblack"); print colored('777      7777 ',"$sscolor2 on_$bgcblack"); } else { print colored('     N',"$sscolor2 on_$bgcblack"); print colored('\\/',"$red on_$bgcblack"); print colored('L',"$sscolor2 on_$bgcblack"); print colored('\\/',"$red on_$bgcblack"); print colored('U      ',"$sscolor2 on_$bgcblack"); } }
sub sssymseven12b { if ($esegpenguinhrs != 1) { print colored(' 7',"$sscolor1 on_$bgcblack"); print colored('L',"bold $sscolor2 on_$bgcblack"); print colored('77777777777777 ',"$sscolor1 on_$bgcblack"); } else { print colored('     L',"$sscolor1 on_$bgcblack"); print colored('/\\',"$red on_$bgcblack"); print colored('U',"$sscolor1 on_$bgcblack"); print colored('/\\',"$red on_$bgcblack"); print colored('I      ',"$sscolor1 on_$bgcblack"); } }
sub sssymseven13b { if ($esegpenguinhrs != 1) { print colored(' B',"bold $sscolor1 on_$bgcblack"); print colored('777777777777777 ',"$sscolor2 on_$bgcblack"); } else { print colored('      lINUx       ',"$sscolor2 on_$bgcblack"); } }

sub sssymwhite { print colored('                  ',"$black on_$bgcblack"); }

sub sssymspining { print colored('||||||||||||||||||',"$boldblack on_$bgcblack"); }

sub sssympayline { print colored('INE            PAY',"$boldwhite on_$bgcgreen"); }

sub ssspinreel {
	#incomplete don't go over 55  #later: why?, it's at 60 now, I must of completed it and forgot to remove this comment
	$ssslotsymbol1 = int(rand(65));
	$ssslotsymbol1a = int(rand(65));
	$ssslotsymbol1b = int(rand(65));
	
	$ssslotsymbol2 = int(rand(65));
	$ssslotsymbol2a = int(rand(65));
	$ssslotsymbol2b = int(rand(65));
	
	$ssslotsymbol3 = int(rand(65));
	$ssslotsymbol3a = int(rand(65));
	$ssslotsymbol3b = int(rand(65));
	$ssmisalign1 = int(rand(60));
	$ssmisalign2 = int(rand(60));
	$ssmisalign3 = int(rand(60));
	if ($ssmisalign1 <= 5) {
		$ssmisalign1 = 1;
	} else {
		$ssmisalign1 = 0;
	}
	
	if ($ssmisalign2 <= 5) {
		$ssmisalign2 = 1;
	} else {
		$ssmisalign2 = 0;
	}
	
	if ($ssmisalign3 <= 5) {
		$ssmisalign3 = 1;
	} else {
		$ssmisalign3 = 0;
	}	
}

#sparkel
#
#bold black magenta bold black 1
#magenta bold black magenta 2
#green      3
#cyan       4
#
#regular
#
#bold magenta 5
#bold green   6
#bold cyan    7
#bold yellow  8
#bold white   9
#red          10
sub sscolorrand {
	$ssslotcolorn = int(rand(45));
	if ($ssslotcolorn <= 9) {
		$sscolorrand = "$red";
	} elsif ($ssslotcolorn <= 18) {
		$sscolorrand = "$boldwhite";
	} elsif ($ssslotcolorn <= 26) {
		$sscolorrand = "$boldyellow";
	} elsif ($ssslotcolorn <= 33) {
		$sscolorrand = "$boldcyan";
	} elsif ($ssslotcolorn <= 39) {
		$sscolorrand = "$boldgreen";
	} else {
		$sscolorrand = "$boldmagenta";
	}

}

sub ssreeltrans {  
	if ($ssslotsymbol1 <= 9) {
	$sssvslot1 = 10;
	$ssr1colora = "$red";
	$ssr1colorb = "$red";
	} elsif ($ssslotsymbol1 <= 18) {
	$sssvslot1 = 9;
	$ssr1colora = "$boldwhite";
	$ssr1colorb = "$boldwhite";
	} elsif ($ssslotsymbol1 <= 26) {
	$sssvslot1 = 8;
	$ssr1colora = "$boldyellow";
	$ssr1colorb = "$boldyellow";
	} elsif ($ssslotsymbol1 <= 33) {
	$sssvslot1 = 7;
	$ssr1colora = "$blue";
	$ssr1colorb = "$blue";
	} elsif ($ssslotsymbol1 <= 39) {
	$sssvslot1 = 6;
	$ssr1colora = "$boldgreen";
	$ssr1colorb = "$boldgreen";
	} elsif ($ssslotsymbol1 <= 44) {
	$sssvslot1 = 5;
	$ssr1colora = "$boldmagenta";
	$ssr1colorb = "$boldmagenta";
	#####################################
	} elsif ($ssslotsymbol1 <= 48) {
	$sssvslot1 = 4;
	$ssr1colora = "$cyan";
	$ssr1colorb = "$boldcyan";
	} elsif ($ssslotsymbol1 <= 51) {
	$sssvslot1 = 3;
	$ssr1colora = "$green";	
	$ssr1colorb = "$boldgreen";
	} elsif ($ssslotsymbol1 <= 53) {
	$sssvslot1 = 2;
	$ssr1colora = "$magenta";	
	$ssr1colorb = "$boldmagenta";
	} elsif ($ssslotsymbol1 == 54) {
	$sssvslot1 = 1;
	$ssr1colora = "$boldblack";	
	$ssr1colorb = "$boldwhite";
	} elsif ($ssslotsymbol1 <= 58) {
		$sssvslot1 = 10;
		$ssr1colora = "$red";
		$ssr1colorb = "$red";
	} elsif ($ssslotsymbol1 >= 59) {
	$sssvslot1 = 12;
	$ssr1colora = "$white";	
	$ssr1colorb = "$cyan";
	} else {
	$sssvslot1 = 0;
	$ssr1colora = "$white";	
	$ssr1colorb = "$white";
	}

	if ($ssslotsymbol2 <= 9) {
	$sssvslot2 = 10;
	$ssr2colora = "$red";
	$ssr2colorb = "$red";
	} elsif ($ssslotsymbol2 <= 18) {
	$sssvslot2 = 9;
	$ssr2colora = "$boldwhite";
	$ssr2colorb = "$boldwhite";
	} elsif ($ssslotsymbol2 <= 26) {
	$sssvslot2 = 8;
	$ssr2colora = "$boldyellow";
	$ssr2colorb = "$boldyellow";
	} elsif ($ssslotsymbol2 <= 33) {
	$sssvslot2 = 7;
	$ssr2colora = "$blue";
	$ssr2colorb = "$blue";
	} elsif ($ssslotsymbol2 <= 39) {
	$sssvslot2 = 6;
	$ssr2colora = "$boldgreen";
	$ssr2colorb = "$boldgreen";
	} elsif ($ssslotsymbol2 <= 44) {
	$sssvslot2 = 5;
	$ssr2colora = "$boldmagenta";
	$ssr2colorb = "$boldmagenta";
	#####################################
	} elsif ($ssslotsymbol2 <= 48) {
	$sssvslot2 = 4;
	$ssr2colora = "$boldcyan";
	$ssr2colorb = "$cyan";
	} elsif ($ssslotsymbol2 <= 51) {
	$sssvslot2 = 3;
	$ssr2colora = "$boldgreen";	
	$ssr2colorb = "$green";
	} elsif ($ssslotsymbol2 <= 53) {
	$sssvslot2 = 2;
	$ssr2colora = "$boldwhite";	
	$ssr2colorb = "$boldblack";
	} elsif ($ssslotsymbol2 == 54) {
	$sssvslot2 = 1;
	$ssr2colora = "$boldmagenta";	
	$ssr2colorb = "$magenta";
	} elsif ($ssslotsymbol2 <= 58) {
		$sssvslot2 = 10;
		$ssr2colora = "$red";
		$ssr2colorb = "$red";
	} elsif ($ssslotsymbol2 >= 59) {
	$sssvslot2 = 12;
	$ssr2colora = "$cyan";	
	$ssr2colorb = "$white";
	} else {
	$sssvslot2 = 0;
	$ssr2colora = "$white";	
	$ssr2colorb = "$white";
	}

	if ($ssslotsymbol3 <= 9) {
	$sssvslot3 = 10;
	$ssr3colora = "$red";
	$ssr3colorb = "$red";
	} elsif ($ssslotsymbol3 <= 18) {
	$sssvslot3 = 9;
	$ssr3colora = "$boldwhite";
	$ssr3colorb = "$boldwhite";
	} elsif ($ssslotsymbol3 <= 26) {
	$sssvslot3 = 8;
	$ssr3colora = "$boldyellow";
	$ssr3colorb = "$boldyellow";
	} elsif ($ssslotsymbol3 <= 33) {
	$sssvslot3 = 7;
	$ssr3colora = "$blue";
	$ssr3colorb = "$blue";
	} elsif ($ssslotsymbol3 <= 39) {
	$sssvslot3 = 6;
	$ssr3colora = "$boldgreen";
	$ssr3colorb = "$boldgreen";
	} elsif ($ssslotsymbol3 <= 44) {
	$sssvslot3 = 5;
	$ssr3colora = "$boldmagenta";
	$ssr3colorb = "$boldmagenta";
	#####################################
	} elsif ($ssslotsymbol3 <= 48) {
	$sssvslot3 = 4;
	$ssr3colora = "$cyan";
	$ssr3colorb = "$boldcyan";
	} elsif ($ssslotsymbol3 <= 51) {
	$sssvslot3 = 3;
	$ssr3colora = "$green";	
	$ssr3colorb = "$boldgreen";
	} elsif ($ssslotsymbol3 <= 53) {
	$sssvslot3 = 2;
	$ssr3colora = "$magenta";	
	$ssr3colorb = "$boldmagenta";
	} elsif ($ssslotsymbol3 == 54) {
	$sssvslot3 = 1;
	$ssr3colora = "$boldblack";	
	$ssr3colorb = "$boldwhite";
	} elsif ($ssslotsymbol3 <= 58) {
		#4 More Red
		$sssvslot3 = 10;
		$ssr3colora = "$red";
		$ssr3colorb = "$red";
	} elsif ($ssslotsymbol3 >= 59) {
	$sssvslot3 = 12;
	$ssr3colora = "$white";	
	$ssr3colorb = "$cyan";
	} else {
	$sssvslot3 = 0;
	$ssr3colora = "$white";	
	$ssr3colorb = "$white";
	}
	
	
	
	if ($ssslotsymbol1a <= 9) {
	$sssvslot1a = 10;
	$ssr1coloraa = "$red";
	$ssr1colorba = "$red";
	} elsif ($ssslotsymbol1a <= 18) {
	$sssvslot1a = 9;
	$ssr1coloraa = "$boldwhite";
	$ssr1colorba = "$boldwhite";
	} elsif ($ssslotsymbol1a <= 26) {
	$sssvslot1a = 8;
	$ssr1coloraa = "$boldyellow";
	$ssr1colorba = "$boldyellow";
	} elsif ($ssslotsymbol1a <= 33) {
	$sssvslot1a = 7;
	$ssr1coloraa = "$blue";
	$ssr1colorba = "$blue";
	} elsif ($ssslotsymbol1a <= 39) {
	$sssvslot1a = 6;
	$ssr1coloraa = "$boldgreen";
	$ssr1colorba = "$boldgreen";
	} elsif ($ssslotsymbol1a <= 44) {
	$sssvslot1a = 5;
	$ssr1coloraa = "$boldmagenta";
	$ssr1colorba = "$boldmagenta";
	#####################################
	} elsif ($ssslotsymbol1a <= 48) {
	$sssvslot1a = 4;
	$ssr1coloraa = "$cyan";
	$ssr1colorba = "$boldcyan";
	} elsif ($ssslotsymbol1a <= 51) {
	$sssvslot1a = 3;
	$ssr1coloraa = "$green";	
	$ssr1colorba = "$boldgreen";
	} elsif ($ssslotsymbol1a <= 53) {
	$sssvslot1a = 2;
	$ssr1coloraa = "$magenta";	
	$ssr1colorba = "$boldmagenta";
	} elsif ($ssslotsymbol1a == 54) {
	$sssvslot1a = 1;
	$ssr1coloraa = "$boldblack";	
	$ssr1colorba = "$boldwhite";
	} elsif ($ssslotsymbol1a <= 58) {
		#4 More Red
		$sssvslot1a = 10;
		$ssr1coloraa = "$red";
		$ssr1colorba = "$red";
	} elsif ($ssslotsymbol1a >= 59) {
	$sssvslot1a = 12;
	$ssr1coloraa = "$white";	
	$ssr1colorba = "$cyan";
	} else {
	$sssvslot1a = 0;
	$ssr1coloraa = "$white";	
	$ssr1colorba = "$white";
	}

	if ($ssslotsymbol2a <= 9) {
	$sssvslot2a = 10;
	$ssr2coloraa = "$red";
	$ssr2colorba = "$red";
	} elsif ($ssslotsymbol2a <= 18) {
	$sssvslot2a = 9;
	$ssr2coloraa = "$boldwhite";
	$ssr2colorba = "$boldwhite";
	} elsif ($ssslotsymbol2a <= 26) {
	$sssvslot2a = 8;
	$ssr2coloraa = "$boldyellow";
	$ssr2colorba = "$boldyellow";
	} elsif ($ssslotsymbol2a <= 33) {
	$sssvslot2a = 7;
	$ssr2coloraa = "$blue";
	$ssr2colorba = "$blue";
	} elsif ($ssslotsymbol2a <= 39) {
	$sssvslot2a = 6;
	$ssr2coloraa = "$boldgreen";
	$ssr2colorba = "$boldgreen";
	} elsif ($ssslotsymbol2a <= 44) {
	$sssvslot2a = 5;
	$ssr2coloraa = "$boldmagenta";
	$ssr2colorba = "$boldmagenta";
	#####################################
	} elsif ($ssslotsymbol2a <= 48) {
	$sssvslot2a = 4;
	$ssr2coloraa = "$boldcyan";
	$ssr2colorba = "$cyan";
	} elsif ($ssslotsymbol2a <= 51) {
	$sssvslot2a = 3;
	$ssr2coloraa = "$boldgreen";	
	$ssr2colorba = "$green";
	} elsif ($ssslotsymbol2a <= 53) {
	$sssvslot2a = 2;
	$ssr2coloraa = "$boldwhite";	
	$ssr2colorba = "$boldblack";
	} elsif ($ssslotsymbol2a == 54) {
	$sssvslot2a = 1;
	$ssr2coloraa = "$boldmagenta";	
	$ssr2colorba = "$magenta";
	} elsif ($ssslotsymbol2a <= 58) {
		#4 More Red
		$sssvslot2a = 10;
		$ssr2coloraa = "$red";
		$ssr2colorba = "$red";
	} elsif ($ssslotsymbol2a >= 59) {
	$sssvslot2a = 12;
	$ssr2coloraa = "$cyan";	
	$ssr2colorba = "$white";
	} else {
	$sssvslot2a = 0;
	$ssr2coloraa = "$white";	
	$ssr2colorba = "$white";
	}

	if ($ssslotsymbol3a <= 9) {
	$sssvslot3a = 10;
	$ssr3coloraa = "$red";
	$ssr3colorba = "$red";
	} elsif ($ssslotsymbol3a <= 18) {
	$sssvslot3a = 9;
	$ssr3coloraa = "$boldwhite";
	$ssr3colorba = "$boldwhite";
	} elsif ($ssslotsymbol3a <= 26) {
	$sssvslot3a = 8;
	$ssr3coloraa = "$boldyellow";
	$ssr3colorba = "$boldyellow";
	} elsif ($ssslotsymbol3a <= 33) {
	$sssvslot3a = 7;
	$ssr3coloraa = "$blue";
	$ssr3colorba = "$blue";
	} elsif ($ssslotsymbol3a <= 39) {
	$sssvslot3a = 6;
	$ssr3coloraa = "$boldgreen";
	$ssr3colorba = "$boldgreen";
	} elsif ($ssslotsymbol3a <= 44) {
	$sssvslot3a = 5;
	$ssr3coloraa = "$boldmagenta";
	$ssr3colorba = "$boldmagenta";
	#####################################
	} elsif ($ssslotsymbol3a <= 48) {
	$sssvslot3a = 4;
	$ssr3coloraa = "$cyan";
	$ssr3colorba = "$boldcyan";
	} elsif ($ssslotsymbol3a <= 51) {
	$sssvslot3a = 3;
	$ssr3coloraa = "$green";	
	$ssr3colorba = "$boldgreen";
	} elsif ($ssslotsymbol3a <= 53) {
	$sssvslot3a = 2;
	$ssr3coloraa = "$magenta";	
	$ssr3colorba = "$boldmagenta";
	} elsif ($ssslotsymbol3a == 54) {
	$sssvslot3a = 1;
	$ssr3coloraa = "$boldblack";	
	$ssr3colorba = "$boldwhite";
	} elsif ($ssslotsymbol3a <= 58) {
		#4 More Red
		$sssvslot3a = 10;
		$ssr3coloraa = "$red";
		$ssr3colorba = "$red";
	} elsif ($ssslotsymbol3a >= 59) {
	$sssvslot3a = 12;
	$ssr3coloraa = "$white";	
	$ssr3colorba = "$cyan";
	} else {
	$sssvslot3a = 0;
	$ssr3coloraa = "$white";	
	$ssr3colorba = "$white";
	}	
	
	
	
	
	if ($ssslotsymbol1b <= 9) {
	$sssvslot1b = 10;
	$ssr1colorab = "$red";
	$ssr1colorbb = "$red";
	} elsif ($ssslotsymbol1b <= 18) {
	$sssvslot1b = 9;
	$ssr1colorab = "$boldwhite";
	$ssr1colorbb = "$boldwhite";
	} elsif ($ssslotsymbol1b <= 26) {
	$sssvslot1b = 8;
	$ssr1colorab = "$boldyellow";
	$ssr1colorbb = "$boldyellow";
	} elsif ($ssslotsymbol1b <= 33) {
	$sssvslot1b = 7;
	$ssr1colorab = "$blue";
	$ssr1colorbb = "$blue";
	} elsif ($ssslotsymbol1b <= 39) {
	$sssvslot1b = 6;
	$ssr1colorab = "$boldgreen";
	$ssr1colorbb = "$boldgreen";
	} elsif ($ssslotsymbol1b <= 44) {
	$sssvslot1b = 5;
	$ssr1colorab = "$boldmagenta";
	$ssr1colorbb = "$boldmagenta";
	#####################################
	} elsif ($ssslotsymbol1b <= 48) {
	$sssvslot1b = 4;
	$ssr1colorab = "$cyan";
	$ssr1colorbb = "$boldcyan";
	} elsif ($ssslotsymbol1b <= 51) {
	$sssvslot1b = 3;
	$ssr1colorab = "$green";	
	$ssr1colorbb = "$boldgreen";
	} elsif ($ssslotsymbol1b <= 53) {
	$sssvslot1b = 2;
	$ssr1colorab = "$magenta";	
	$ssr1colorbb = "$boldmagenta";
	} elsif ($ssslotsymbol1b == 54) {
	$sssvslot1b = 1;
	$ssr1colorab = "$boldblack";	
	$ssr1colorbb = "$boldwhite";
	} elsif ($ssslotsymbol1b <= 58) {
		#4 More Red
		$sssvslot1b = 10;
		$ssr1colorab = "$red";
		$ssr1colorbb = "$red";
	} elsif ($ssslotsymbol1b >= 59) {
	$sssvslot1b = 12;
	$ssr1colorab = "$white";	
	$ssr1colorbb = "$cyan";
	} else {
	$sssvslot1b = 0;
	$ssr1colorab = "$white";	
	$ssr1colorbb = "$white";
	}

	if ($ssslotsymbol2b <= 9) {
	$sssvslot2b = 10;
	$ssr2colorab = "$red";
	$ssr2colorbb = "$red";
	} elsif ($ssslotsymbol2b <= 18) {
	$sssvslot2b = 9;
	$ssr2colorab = "$boldwhite";
	$ssr2colorbb = "$boldwhite";
	} elsif ($ssslotsymbol2b <= 26) {
	$sssvslot2b = 8;
	$ssr2colorab = "$boldyellow";
	$ssr2colorbb = "$boldyellow";
	} elsif ($ssslotsymbol2b <= 33) {
	$sssvslot2b = 7;
	$ssr2colorab = "$blue";
	$ssr2colorbb = "$blue";
	} elsif ($ssslotsymbol2b <= 39) {
	$sssvslot2b = 6;
	$ssr2colorab = "$boldgreen";
	$ssr2colorbb = "$boldgreen";
	} elsif ($ssslotsymbol2b <= 44) {
	$sssvslot2b = 5;
	$ssr2colorab = "$boldmagenta";
	$ssr2colorbb = "$boldmagenta";
	#####################################
	} elsif ($ssslotsymbol2b <= 48) {
	$sssvslot2b = 4;
	$ssr2colorab = "$boldcyan";
	$ssr2colorbb = "$cyan";
	} elsif ($ssslotsymbol2b <= 51) {
	$sssvslot2b = 3;
	$ssr2colorab = "$boldgreen";	
	$ssr2colorbb = "$green";
	} elsif ($ssslotsymbol2b <= 53) {
	$sssvslot2b = 2;
	$ssr2colorab = "$boldwhite";	
	$ssr2colorbb = "$boldblack";
	} elsif ($ssslotsymbol2b == 54) {
	$sssvslot2b = 1;
	$ssr2colorab = "$boldmagenta";	
	$ssr2colorbb = "$magenta";
	} elsif ($ssslotsymbol2b <= 58) {
		#4 More Red
		$sssvslot2b = 10;
		$ssr2colorab = "$red";
		$ssr2colorbb = "$red";
	} elsif ($ssslotsymbol2b >= 59) {
	$sssvslot2b = 12;
	$ssr2colorab = "$cyan";	
	$ssr2colorbb = "$white";
	} else {
	$sssvslot2b = 0;
	$ssr2colorab = "$white";	
	$ssr2colorbb = "$white";
	}

	if ($ssslotsymbol3b <= 9) {
	$sssvslot3b = 10;
	$ssr3colorab = "$red";
	$ssr3colorbb = "$red";
	} elsif ($ssslotsymbol3b <= 18) {
	$sssvslot3b = 9;
	$ssr3colorab = "$boldwhite";
	$ssr3colorbb = "$boldwhite";
	} elsif ($ssslotsymbol3b <= 26) {
	$sssvslot3b = 8;
	$ssr3colorab = "$boldyellow";
	$ssr3colorbb = "$boldyellow";
	} elsif ($ssslotsymbol3b <= 33) {
	$sssvslot3b = 7;
	$ssr3colorab = "$blue";
	$ssr3colorbb = "$blue";
	} elsif ($ssslotsymbol3b <= 39) {
	$sssvslot3b = 6;
	$ssr3colorab = "$boldgreen";
	$ssr3colorbb = "$boldgreen";
	} elsif ($ssslotsymbol3b <= 44) {
	$sssvslot3b = 5;
	$ssr3colorab = "$boldmagenta";
	$ssr3colorbb = "$boldmagenta";
	#####################################
	} elsif ($ssslotsymbol3b <= 48) {
	$sssvslot3b = 4;
	$ssr3colorab = "$cyan";
	$ssr3colorbb = "$boldcyan";
	} elsif ($ssslotsymbol3b <= 51) {
	$sssvslot3b = 3;
	$ssr3colorab = "$green";	
	$ssr3colorbb = "$boldgreen";
	} elsif ($ssslotsymbol3b <= 53) {
	$sssvslot3b = 2;
	$ssr3colorab = "$magenta";	
	$ssr3colorbb = "$boldmagenta";
	} elsif ($ssslotsymbol3b == 54) {
	$sssvslot3b = 1;
	$ssr3colorab = "$boldblack";	
	$ssr3colorbb = "$boldwhite";
	} elsif ($ssslotsymbol3b <= 58) {
		#4 More Red
		$sssvslot3b = 10;
		$ssr3colorab = "$red";
		$ssr3colorbb = "$red";
	} elsif ($ssslotsymbol3b >= 59) {
	$sssvslot3b = 12;
	$ssr3colorab = "$white";	
	$ssr3colorbb = "$cyan";
	} else {
	$sssvslot3b = 0;
	$ssr3colorab = "$white";	
	$ssr3colorbb = "$white";
	}	
	
}

sub ssslotm5 {
		sssymseven3();	
}

sub ssslotm4 {
		sssymseven4();	
}

sub ssslotm3 {
		sssymseven5();	
}


sub ssslotm2 {
		sssymseven6();	
}

sub ssslotm1 {
	if ($ssslot1 eq 'spining') {
		sssymspining();
	} elsif ($ssslot1 eq 'misaliga') {
		sssymwhite();
	} elsif ($ssslot1 eq 'misalig') {
		if ($ssslotmis1 == 12) {
			sssymseven7b();
		} elsif ($ssslotmis1 <= 4) {
			sssymseven7a();
		} elsif ($ssslotmis1 >= 5) {
			sssymseven7();
		} else {
			sssymwhite();
		}
	} elsif ($ssslot1 eq 'misaligb') {
		sssymwhite();
	} elsif ($ssslot1 == 11) {
		sssymseven7();	
	} else {
		sssymwhite();
	}

}					
			
sub ssslot1 {
	if ($ssslot1 eq 'spining') {
		sssymspining();
	} elsif ($ssslot1 eq 'misaliga') {
		sssymwhite();
	} elsif ($ssslot1 eq 'misalig') {
		if ($ssslotmis1 == 12) {
			sssymseven8b();
		} elsif ($ssslotmis1 <= 4) {
			sssymseven8a();
		} elsif ($ssslotmis1 >= 5) {
			sssymseven8();
		} else {
			sssymwhite();
		}
	} elsif ($ssslot1 eq 'misaligb') {
		if ($ssslotmis1 == 12) {
			sssymseven8b();
		} elsif ($ssslotmis1 <= 4) {
			sssymseven8a();
		} elsif ($ssslotmis1 >= 5) {
			sssymseven8();
		} else {
			sssymwhite();
		}	
	} elsif ($ssslot1 == 12) {
		sssymseven1b();
	} elsif ($ssslot1 <= 4) {
		sssymseven1a();
	} elsif ($ssslot1 >= 5) {
		sssymseven1();		
	} else {
		sssymwhite();
	}

}

sub ssslot2 {
	if ($ssslot2 eq 'spining') {
		sssymspining();
	} elsif ($ssslot2 eq 'misaliga') {
		sssymwhite();
	} elsif ($ssslot2 eq 'misalig') {
		if ($ssslotmis2 == 12) {
			sssymseven9b();
		} elsif ($ssslotmis2 <= 4) {
			sssymseven9a();
		} elsif ($ssslotmis2 >= 5) {
			sssymseven9();
		} else {
			sssymwhite();
		}
	} elsif ($ssslot2 eq 'misaligb') {
		if ($ssslotmis2 == 12) {
			sssymseven9b();
		} elsif ($ssslotmis2 <= 4) {
			sssymseven9a();
		} elsif ($ssslotmis2 >= 5) {
			sssymseven9();
		} else {
			sssymwhite();
		}
	} elsif ($ssslot2 == 12) {
		sssymseven2b();
	} elsif ($ssslot2 <= 4) {
		sssymseven2a();
	} elsif ($ssslot2 >= 5) {
		sssymseven2();			
	} else {
		sssymwhite();
	}

}	
	
sub ssslot3 {
	if ($ssslot3 eq 'spining') {
		sssymspining();
	} elsif ($ssslot3 eq 'misaliga') {
		sssymwhite();
	} elsif ($ssslot3 eq 'misalig') {
		if ($ssslotmis3 == 12) {
			sssymseven10b();
		} elsif ($ssslotmis3 <= 4) {
			sssymseven10a();
		} elsif ($ssslotmis3 >= 5) {
			sssymseven10();
		} else {
			sssymwhite();
		}
	} elsif ($ssslot3 eq 'misaligb') {
		if ($ssslotmis3 == 12) {
			sssymseven10b();
		} elsif ($ssslotmis3 <= 4) {
			sssymseven10a();
		} elsif ($ssslotmis3 >= 5) {
			sssymseven10();
		} else {
			sssymwhite();
		}
	} elsif ($ssslot3 == 12) {
		sssymseven3b();	
	} elsif ($ssslot3 <= 4) {
		sssymseven3a();
	} elsif ($ssslot3 >= 5) {
		sssymseven3();		
	} else {
		sssymwhite();
	}

}

sub ssslot4 {
	if ($ssslot4 eq 'spining') {
		sssymspining();
	} elsif ($ssslot4 eq 'misaliga') {
		sssymwhite();
	} elsif ($ssslot4 eq 'misalig') {
		if ($ssslotmis4 == 12) {
			sssymseven11b();
		} elsif ($ssslotmis4 <= 4) {
			sssymseven11a();
		} elsif ($ssslotmis4 >= 5) {
			sssymseven11();
		} else {
			sssymwhite();
		}
	} elsif ($ssslot4 eq 'misaligb') {
		if ($ssslotmis4 == 12) {
			sssymseven11b();
		} elsif ($ssslotmis4 <= 4) {
			sssymseven11a();
		} elsif ($ssslotmis4 >= 5) {
			sssymseven11();
		} else {
			sssymwhite();
		}
	} elsif ($ssslot4 == 12) {
		sssymseven4b();	
	} elsif ($ssslot4 <= 4) {
		sssymseven4a();
	} elsif ($ssslot4 >= 5) {
		sssymseven4();	
	} else {
		sssymwhite();
	}

}
	
sub ssslot5 {
	if ($ssslot5 eq 'spining') {
		sssymspining();
	} elsif ($ssslot5 eq 'misaliga') {
		sssymwhite();
	} elsif ($ssslot5 eq 'misalig') {
		if ($ssslotmis5 == 12) {
			sssymseven12b();
		} elsif ($ssslotmis5 <= 4) {
			sssymseven12a();
		} elsif ($ssslotmis5 >= 5) {
			sssymseven12();
		} else {
			sssymwhite();
		}
	} elsif ($ssslot5 eq 'misaligb') {
		sssymwhite();
	} elsif ($ssslot5 == 12) {
		sssymseven5b();	
	} elsif ($ssslot5 <= 4) {
		sssymseven5a();
	} elsif ($ssslot5 >= 5) {
		sssymseven5();		
	} else {
		sssymwhite();
	}

}	
	
sub ssslot6 {
	if ($ssslot6 eq 'spining') {
		sssymspining();
	} elsif ($ssslot6 eq 'misaliga') {
		sssymwhite();
	} elsif ($ssslot6 eq 'misalig') {
		if ($ssslotmis6 == 12) {
			sssymseven13b();
		} elsif ($ssslotmis6 <= 4) {
			sssymseven13a();
		} elsif ($ssslotmis6 >= 5) {
			sssymseven13();
		} else {
			sssymwhite();
		}
	} elsif ($ssslot6 eq 'misaligb') {
		sssymwhite();
	} elsif ($ssslot6 == 12) {
		sssymseven6b();
	} elsif ($ssslot6 <= 4) {
		sssymseven6a();
	} elsif ($ssslot6 >= 5) {
		sssymseven6();	
	} else {
		sssymwhite();
	}

}
	
sub ssslot7 {
	sssympayline();
}

sub ssslot8 {
	if ($ssslot8 eq 'spining') {
		sssymspining();
	} elsif ($ssslot8 eq 'misaliga') {
		sssymwhite();
	} elsif ($ssslot8 eq 'misalig') {
		if ($ssslotmis8 == 12) {
			sssymseven1b();
		} elsif ($ssslotmis8 <= 4) {
			sssymseven1a();
		} elsif ($ssslotmis8 >= 5) {
			sssymseven1();
		} else {
			sssymwhite();
		}
	} elsif ($ssslot8 eq 'misaligb') {
		sssymwhite();
	} elsif ($ssslot8 == 12) {
		sssymseven8b();
	} elsif ($ssslot8 <= 4) {
		sssymseven8a();
	} elsif ($ssslot8 >= 5) {
		sssymseven8();	
	} else {
		sssymwhite();
	}

}

sub ssslot9 {
	if ($ssslot9 eq 'spining') {
		sssymspining();
	} elsif ($ssslot9 eq 'misaliga') {
		sssymwhite();
	} elsif ($ssslot9 eq 'misalig') {
		if ($ssslotmis9 == 12) {
			sssymseven2b();
		} elsif ($ssslotmis9 <= 4) {
			sssymseven2a();
		} elsif ($ssslotmis9 >= 5) {
			sssymseven2();
		} else {
			sssymwhite();
		}
	} elsif ($ssslot9 eq 'misaligb') {
		sssymwhite();
	} elsif ($ssslot9 == 12) {
		sssymseven9b();
	} elsif ($ssslot9 <= 4) {
		sssymseven9a();
	} elsif ($ssslot9 >= 5) {
		sssymseven9();	
	} else {
		sssymwhite();
	}

}

sub ssslot10 {
	if ($ssslot10 eq 'spining') {
		sssymspining();
	} elsif ($ssslot10 eq 'misaliga') {
		if ($ssslotmis10 == 12) {
			sssymseven3b();
		} elsif ($ssslotmis10 <= 4) {
			sssymseven3a();
		} elsif ($ssslotmis10 >= 5) {
			sssymseven3();
		}
	} elsif ($ssslot10 eq 'misalig') {
		if ($ssslotmis10 == 12) {
			sssymseven3b();
		} elsif ($ssslotmis10 <= 4) {
			sssymseven3a();
		} elsif ($ssslotmis10 >= 5) {
			sssymseven3();
		} else {
			sssymwhite();
		}
	} elsif ($ssslot10 eq 'misaligb') {
		sssymwhite();
	} elsif ($ssslot10 == 12) {
		sssymseven10b();
	} elsif ($ssslot10 <= 4) {
		sssymseven10a();
	} elsif ($ssslot10 >= 5) {
		sssymseven10();	
	} else {
		sssymwhite();
	}

}

sub ssslot11 {
	if ($ssslot11 eq 'spining') {
		sssymspining();
	} elsif ($ssslot11 eq 'misaliga') {
		if ($ssslotmis11 == 12) {
			sssymseven4b();
		} elsif ($ssslotmis11 <= 4) {
			sssymseven4a();
		} elsif ($ssslotmis11 >= 5) {
			sssymseven4();
		} else {
			sssymwhite();
		}
	} elsif ($ssslot11 eq 'misalig') {
		if ($ssslotmis11 == 12) {
			sssymseven4b();
		} elsif ($ssslotmis11 <= 4) {
			sssymseven4a();
		} elsif ($ssslotmis11 >= 5) {
			sssymseven4();
		} else {
			sssymwhite();
		}
	} elsif ($ssslot11 eq 'misaligb') {
		sssymwhite();
	} elsif ($ssslot11 == 12) {
		sssymseven11b();
	} elsif ($ssslot11 <= 4) {
		sssymseven11a();
	} elsif ($ssslot11 >= 5) {
		sssymseven11();	
	} else {
		sssymwhite();
	}

}
	
sub ssslot12 {
	if ($ssslot12 eq 'spining') {
		sssymspining();
	} elsif ($ssslot12 eq 'misaliga') {
		if ($ssslotmis12 == 12) {
			sssymseven5b();
		} elsif ($ssslotmis12 <= 4) {
			sssymseven5a();
		} elsif ($ssslotmis12 >= 5) {
			sssymseven5();
		} else {
			sssymwhite();
		}
	} elsif ($ssslot12 eq 'misalig') {
		if ($ssslotmis12 == 12) {
			sssymseven5b();
		} elsif ($ssslotmis12 <= 4) {
			sssymseven5a();
		} elsif ($ssslotmis12 >= 5) {
			sssymseven5();
		} else {
			sssymwhite();
		}
	} elsif ($ssslot12 eq 'misaligb') {
		sssymwhite();
	} elsif ($ssslot12 == 12) {
		sssymseven12b();
	} elsif ($ssslot12 <= 4) {
		sssymseven12a();
	} elsif ($ssslot12 >= 5) {
		sssymseven12();	
	} else {
		sssymwhite();
	}

}	
	
sub ssslot13 {
	if ($ssslot13 eq 'spining') {
		sssymspining();
	} elsif ($ssslot13 eq 'misaliga') {
		if ($ssslotmis13 == 12) {
			sssymseven6b();
		} elsif ($ssslotmis13 <= 4) {
			sssymseven6a();
		} elsif ($ssslotmis13 >= 5) {
			sssymseven6();
		} else {
			sssymwhite();
		}
	} elsif ($ssslot13 eq 'misalig') {
		if ($ssslotmis13 == 12) {
			sssymseven6b();
		} elsif ($ssslotmis13 <= 4) {
			sssymseven6a();
		} elsif ($ssslotmis13 >= 5) {
			sssymseven6();
		} else {
			sssymwhite();
		}
	} elsif ($ssslot13 eq 'misaligb') {
		sssymwhite();
	} elsif ($ssslot13 == 12) {
		sssymseven13b();
	} elsif ($ssslot13 <= 4) {
		sssymseven13a();
	} elsif ($ssslot13 >= 5) {
		sssymseven13();	
	} else {
		sssymwhite();
	}

}

sub ssslotp1 {
	if ($ssslot13 eq 'spining') {
		sssymspining();
	} elsif ($ssslot13 eq 'misaliga') {
		sssymwhite();
	} elsif ($ssslot13 eq 'misalig') {
		if ($ssslotmis13 == 12) {
			sssymseven7b();
		} elsif ($ssslotmis13 <= 4) {
			sssymseven7a();
		} elsif ($ssslotmis13 >= 5) {
			sssymseven7();
		} else {
			sssymwhite();
		}
	} elsif ($ssslot13 eq 'misaligb') {
		sssymwhite();
	} elsif ($ssslot13 == 11) {
		sssymseven7();
	} else {
		sssymwhite();
	}

}

sub ssreel1 {
	$ssreel = 1;
	if ($ssreelspin == 3) {
		$ssslot1 = 'spining';
		$ssslot2 = 'spining';
		$ssslot3 = 'spining';
		$ssslot4 = 'spining';
		$ssslot5 = 'spining';
		$ssslot6 = 'spining';
		$ssslot7 = 'spining';
		$ssslot8 = 'spining';
		$ssslot9 = 'spining';
		$ssslot10 = 'spining';
		$ssslot11 = 'spining';
		$ssslot12 = 'spining';
		$ssslot13 = 'spining';
		$ssslot14 = 'spining';
	} elsif ($ssmisalign1 == 1) {
		$ssslot1 = 'misalig';
		$ssslot2 = 'misalig';
		$ssslot3 = 'misalig';
		$ssslot4 = 'misalig';
		$ssslot5 = 'misalig';
		$ssslot6 = 'misalig';
		$ssslot7 = 'misalig';
		$ssslot8 = 'misalig';
		$ssslot9 = 'misalig';
		$ssslot10 = 'misalig';
		$ssslot11 = 'misalig';
		$ssslot12 = 'misalig';
		$ssslot13 = 'misalig';
		$ssslot14 = 'misalig';
		$ssslotmis1 = $sssvslot1;
		$ssslotmis2 = $sssvslot1;
		$ssslotmis3 = $sssvslot1;
		$ssslotmis4 = $sssvslot1;
		$ssslotmis5 = $sssvslot1;
		$ssslotmis6 = $sssvslot1;
		$ssslotmis7 = $sssvslot1;
		$ssslotmis8 = $sssvslot1b;
		$ssslotmis9 = $sssvslot1b;
		$ssslotmis10 = $sssvslot1b;
		$ssslotmis11 = $sssvslot1b;
		$ssslotmis12 = $sssvslot1b;
		$ssslotmis13 = $sssvslot1b;
		$ssslotmis14 = $sssvslot1b;
	} else {
		$ssslot1 = $sssvslot1;
		$ssslot2 = $sssvslot1;
		$ssslot3 = $sssvslot1;
		$ssslot4 = $sssvslot1;
		$ssslot5 = $sssvslot1;
		$ssslot6 = $sssvslot1;
		$ssslot7 = $sssvslot1;
		$ssslot8 = $sssvslot1;
		$ssslot9 = $sssvslot1;
		$ssslot10 = $sssvslot1;
		$ssslot11 = $sssvslot1;
		$ssslot12 = $sssvslot1;
		$ssslot13 = $sssvslot1;
		$ssslot14 = $sssvslot1;
	}
}

sub ssreel2 {
	$ssreel = 2;
	if ($ssreelspin >= 2) {
		$ssslot1 = 'spining';
		$ssslot2 = 'spining';
		$ssslot3 = 'spining';
		$ssslot4 = 'spining';
		$ssslot5 = 'spining';
		$ssslot6 = 'spining';
		$ssslot7 = 'spining';
		$ssslot8 = 'spining';
		$ssslot9 = 'spining';
		$ssslot10 = 'spining';
		$ssslot11 = 'spining';
		$ssslot12 = 'spining';
		$ssslot13 = 'spining';
		$ssslot14 = 'spining';
	} elsif ($ssmisalign2 == 1) {
		$ssslot1 = 'misalig';
		$ssslot2 = 'misalig';
		$ssslot3 = 'misalig';
		$ssslot4 = 'misalig';
		$ssslot5 = 'misalig';
		$ssslot6 = 'misalig';
		$ssslot7 = 'misalig';
		$ssslot8 = 'misalig';
		$ssslot9 = 'misalig';
		$ssslot10 = 'misalig';
		$ssslot11 = 'misalig';
		$ssslot12 = 'misalig';
		$ssslot13 = 'misalig';
		$ssslot14 = 'misalig';
		$ssslotmis1 = $sssvslot2;
		$ssslotmis2 = $sssvslot2;
		$ssslotmis3 = $sssvslot2;
		$ssslotmis4 = $sssvslot2;
		$ssslotmis5 = $sssvslot2;
		$ssslotmis6 = $sssvslot2;
		$ssslotmis7 = $sssvslot2;
		$ssslotmis8 = $sssvslot2b;
		$ssslotmis9 = $sssvslot2b;
		$ssslotmis10 = $sssvslot2b;
		$ssslotmis11 = $sssvslot2b;
		$ssslotmis12 = $sssvslot2b;
		$ssslotmis13 = $sssvslot2b;
		$ssslotmis14 = $sssvslot2b;
	} else {
		$ssslot1 = $sssvslot2;
		$ssslot2 = $sssvslot2;
		$ssslot3 = $sssvslot2;
		$ssslot4 = $sssvslot2;
		$ssslot5 = $sssvslot2;
		$ssslot6 = $sssvslot2;
		$ssslot7 = $sssvslot2;
		$ssslot8 = $sssvslot2;
		$ssslot9 = $sssvslot2;
		$ssslot10 = $sssvslot2;
		$ssslot11 = $sssvslot2;
		$ssslot12 = $sssvslot2;
		$ssslot13 = $sssvslot2;
		$ssslot14 = $sssvslot2;
	}
}

sub ssreel3 {
	$ssreel = 3;
	if ($ssreelspin >= 1) {
		$ssslot1 = 'spining';
		$ssslot2 = 'spining';
		$ssslot3 = 'spining';
		$ssslot4 = 'spining';
		$ssslot5 = 'spining';
		$ssslot6 = 'spining';
		$ssslot7 = 'spining';
		$ssslot8 = 'spining';
		$ssslot9 = 'spining';
		$ssslot10 = 'spining';
		$ssslot11 = 'spining';
		$ssslot12 = 'spining';
		$ssslot13 = 'spining';
		$ssslot14 = 'spining';
	} elsif ($ssmisalign3 == 1) {
		$ssslot1 = 'misalig';
		$ssslot2 = 'misalig';
		$ssslot3 = 'misalig';
		$ssslot4 = 'misalig';
		$ssslot5 = 'misalig';
		$ssslot6 = 'misalig';
		$ssslot7 = 'misalig';
		$ssslot8 = 'misalig';
		$ssslot9 = 'misalig';
		$ssslot10 = 'misalig';
		$ssslot11 = 'misalig';
		$ssslot12 = 'misalig';
		$ssslot13 = 'misalig';
		$ssslot14 = 'misalig';
		$ssslotmis1 = $sssvslot3;
		$ssslotmis2 = $sssvslot3;
		$ssslotmis3 = $sssvslot3;
		$ssslotmis4 = $sssvslot3;
		$ssslotmis5 = $sssvslot3;
		$ssslotmis6 = $sssvslot3;
		$ssslotmis7 = $sssvslot3;
		$ssslotmis8 = $sssvslot3b;
		$ssslotmis9 = $sssvslot3b;
		$ssslotmis10 = $sssvslot3b;
		$ssslotmis11 = $sssvslot3b;
		$ssslotmis12 = $sssvslot3b;
		$ssslotmis13 = $sssvslot3b;
		$ssslotmis14 = $sssvslot3b;
	} else {
		$ssslot1 = $sssvslot3;
		$ssslot2 = $sssvslot3;
		$ssslot3 = $sssvslot3;
		$ssslot4 = $sssvslot3;
		$ssslot5 = $sssvslot3;
		$ssslot6 = $sssvslot3;
		$ssslot7 = $sssvslot3;
		$ssslot8 = $sssvslot3;
		$ssslot9 = $sssvslot3;
		$ssslot10 = $sssvslot3;
		$ssslot11 = $sssvslot3;
		$ssslot12 = $sssvslot3;
		$ssslot13 = $sssvslot3;
		$ssslot14 = $sssvslot3;
	}
}

sub ssreel1b {
	$ssreel = 7;
	if ($ssreelspin == 3) {
		$ssslot1 = 'spining';
		$ssslot2 = 'spining';
		$ssslot3 = 'spining';
		$ssslot4 = 'spining';
		$ssslot5 = 'spining';
		$ssslot6 = 'spining';
		$ssslot7 = 'spining';
		$ssslot8 = 'spining';
		$ssslot9 = 'spining';
		$ssslot10 = 'spining';
		$ssslot11 = 'spining';
		$ssslot12 = 'spining';
		$ssslot13 = 'spining';
		$ssslot14 = 'spining';
	} elsif ($ssmisalign1 == 1) {
		$ssslot1 = 'misaligb';
		$ssslot2 = 'misaligb';
		$ssslot3 = 'misaligb';
		$ssslot4 = 'misaligb';
		$ssslot5 = 'misaligb';
		$ssslot6 = 'misaligb';
		$ssslot7 = 'misaligb';
		$ssslot8 = 'misaligb';
		$ssslot9 = 'misaligb';
		$ssslot10 = 'misaligb';
		$ssslot11 = 'misaligb';
		$ssslot12 = 'misaligb';
		$ssslot13 = 'misaligb';
		$ssslot14 = 'misaligb';
		$ssslotmis1 = $sssvslot1b;
		$ssslotmis2 = $sssvslot1b;
		$ssslotmis3 = $sssvslot1b;
		$ssslotmis4 = $sssvslot1b;
		$ssslotmis5 = $sssvslot1b;
		$ssslotmis6 = $sssvslot1b;
		$ssslotmis7 = $sssvslot1b;
		$ssslotmis8 = $sssvslot1b;
		$ssslotmis9 = $sssvslot1b;
		$ssslotmis10 = $sssvslot1b;
		$ssslotmis11 = $sssvslot1b;
		$ssslotmis12 = $sssvslot1b;
		$ssslotmis13 = $sssvslot1b;
		$ssslotmis14 = $sssvslot1b;
	} else {
		$ssslot1 = $sssvslot1b;
		$ssslot2 = $sssvslot1b;
		$ssslot3 = $sssvslot1b;
		$ssslot4 = $sssvslot1b;
		$ssslot5 = $sssvslot1b;
		$ssslot6 = $sssvslot1b;
		$ssslot7 = $sssvslot1b;
		$ssslot8 = $sssvslot1b;
		$ssslot9 = $sssvslot1b;
		$ssslot10 = $sssvslot1b;
		$ssslot11 = $sssvslot1b;
		$ssslot12 = $sssvslot1b;
		$ssslot13 = $sssvslot1b;
		$ssslot14 = $sssvslot1b;
	}
}

sub ssreel2b {
	$ssreel = 8;
	if ($ssreelspin >= 2) {
		$ssslot1 = 'spining';
		$ssslot2 = 'spining';
		$ssslot3 = 'spining';
		$ssslot4 = 'spining';
		$ssslot5 = 'spining';
		$ssslot6 = 'spining';
		$ssslot7 = 'spining';
		$ssslot8 = 'spining';
		$ssslot9 = 'spining';
		$ssslot10 = 'spining';
		$ssslot11 = 'spining';
		$ssslot12 = 'spining';
		$ssslot13 = 'spining';
		$ssslot14 = 'spining';
	} elsif ($ssmisalign2 == 1) {
		$ssslot1 = 'misaligb';
		$ssslot2 = 'misaligb';
		$ssslot3 = 'misaligb';
		$ssslot4 = 'misaligb';
		$ssslot5 = 'misaligb';
		$ssslot6 = 'misaligb';
		$ssslot7 = 'misaligb';
		$ssslot8 = 'misaligb';
		$ssslot9 = 'misaligb';
		$ssslot10 = 'misaligb';
		$ssslot11 = 'misaligb';
		$ssslot12 = 'misaligb';
		$ssslot13 = 'misaligb';
		$ssslot14 = 'misaligb';
		$ssslotmis1 = $sssvslot2b;
		$ssslotmis2 = $sssvslot2b;
		$ssslotmis3 = $sssvslot2b;
		$ssslotmis4 = $sssvslot2b;
		$ssslotmis5 = $sssvslot2b;
		$ssslotmis6 = $sssvslot2b;
		$ssslotmis7 = $sssvslot2b;
		$ssslotmis8 = $sssvslot2b;
		$ssslotmis9 = $sssvslot2b;
		$ssslotmis10 = $sssvslot2b;
		$ssslotmis11 = $sssvslot2b;
		$ssslotmis12 = $sssvslot2b;
		$ssslotmis13 = $sssvslot2b;
		$ssslotmis14 = $sssvslot2b;
	} else {
		$ssslot1 = $sssvslot2b;
		$ssslot2 = $sssvslot2b;
		$ssslot3 = $sssvslot2b;
		$ssslot4 = $sssvslot2b;
		$ssslot5 = $sssvslot2b;
		$ssslot6 = $sssvslot2b;
		$ssslot7 = $sssvslot2b;
		$ssslot8 = $sssvslot2b;
		$ssslot9 = $sssvslot2b;
		$ssslot10 = $sssvslot2b;
		$ssslot11 = $sssvslot2b;
		$ssslot12 = $sssvslot2b;
		$ssslot13 = $sssvslot2b;
		$ssslot14 = $sssvslot2b;
	}
}

sub ssreel3b {
	$ssreel = 9;
	if ($ssreelspin >= 1) {
		$ssslot1 = 'spining';
		$ssslot2 = 'spining';
		$ssslot3 = 'spining';
		$ssslot4 = 'spining';
		$ssslot5 = 'spining';
		$ssslot6 = 'spining';
		$ssslot7 = 'spining';
		$ssslot8 = 'spining';
		$ssslot9 = 'spining';
		$ssslot10 = 'spining';
		$ssslot11 = 'spining';
		$ssslot12 = 'spining';
		$ssslot13 = 'spining';
		$ssslot14 = 'spining';
	} elsif ($ssmisalign3 == 1) {
		$ssslot1 = 'misaligb';
		$ssslot2 = 'misaligb';
		$ssslot3 = 'misaligb';
		$ssslot4 = 'misaligb';
		$ssslot5 = 'misaligb';
		$ssslot6 = 'misaligb';
		$ssslot7 = 'misaligb';
		$ssslot8 = 'misaligb';
		$ssslot9 = 'misaligb';
		$ssslot10 = 'misaligb';
		$ssslot11 = 'misaligb';
		$ssslot12 = 'misaligb';
		$ssslot13 = 'misaligb';
		$ssslot14 = 'misaligb';
		$ssslotmis1 = $sssvslot3b;
		$ssslotmis2 = $sssvslot3b;
		$ssslotmis3 = $sssvslot3b;
		$ssslotmis4 = $sssvslot3b;
		$ssslotmis5 = $sssvslot3b;
		$ssslotmis6 = $sssvslot3b;
		$ssslotmis7 = $sssvslot3b;
		$ssslotmis8 = $sssvslot3b;
		$ssslotmis9 = $sssvslot3b;
		$ssslotmis10 = $sssvslot3b;
		$ssslotmis11 = $sssvslot3b;
		$ssslotmis12 = $sssvslot3b;
		$ssslotmis13 = $sssvslot3b;
		$ssslotmis14 = $sssvslot3b;
	} else {
		$ssslot1 = $sssvslot3b;
		$ssslot2 = $sssvslot3b;
		$ssslot3 = $sssvslot3b;
		$ssslot4 = $sssvslot3b;
		$ssslot5 = $sssvslot3b;
		$ssslot6 = $sssvslot3b;
		$ssslot7 = $sssvslot3b;
		$ssslot8 = $sssvslot3b;
		$ssslot9 = $sssvslot3b;
		$ssslot10 = $sssvslot3b;
		$ssslot11 = $sssvslot3b;
		$ssslot12 = $sssvslot3b;
		$ssslot13 = $sssvslot3b;
		$ssslot14 = $sssvslot3b;
	}
}

sub ssreel1a {
	$ssreel = 4;
	if ($ssreelspin == 3) {
		$ssslot1 = 'spining';
		$ssslot2 = 'spining';
		$ssslot3 = 'spining';
		$ssslot4 = 'spining';
		$ssslot5 = 'spining';
		$ssslot6 = 'spining';
		$ssslot7 = 'spining';
		$ssslot8 = 'spining';
		$ssslot9 = 'spining';
		$ssslot10 = 'spining';
		$ssslot11 = 'spining';
		$ssslot12 = 'spining';
		$ssslot13 = 'spining';
		$ssslot14 = 'spining';
	} elsif ($ssmisalign1 == 1) {
		$ssslot1 = 'misaliga';
		$ssslot2 = 'misaliga';
		$ssslot3 = 'misaliga';
		$ssslot4 = 'misaliga';
		$ssslot5 = 'misaliga';
		$ssslot6 = 'misaliga';
		$ssslot7 = 'misaliga';
		$ssslot8 = 'misaliga';
		$ssslot9 = 'misaliga';
		$ssslot10 = 'misaliga';
		$ssslot11 = 'misaliga';
		$ssslot12 = 'misaliga';
		$ssslot13 = 'misaliga';
		$ssslot14 = 'misaliga';
		$ssslotmis1 = $sssvslot1;
		$ssslotmis2 = $sssvslot1;
		$ssslotmis3 = $sssvslot1;
		$ssslotmis4 = $sssvslot1;
		$ssslotmis5 = $sssvslot1;
		$ssslotmis6 = $sssvslot1;
		$ssslotmis7 = $sssvslot1;
		$ssslotmis8 = $sssvslot1;
		$ssslotmis9 = $sssvslot1;
		$ssslotmis10 = $sssvslot1;
		$ssslotmis11 = $sssvslot1;
		$ssslotmis12 = $sssvslot1;
		$ssslotmis13 = $sssvslot1;
		$ssslotmis14 = $sssvslot1;
	} else {
		$ssslot1 = $sssvslot1a;
		$ssslot2 = $sssvslot1a;
		$ssslot3 = $sssvslot1a;
		$ssslot4 = $sssvslot1a;
		$ssslot5 = $sssvslot1a;
		$ssslot6 = $sssvslot1a;
		$ssslot7 = $sssvslot1a;
		$ssslot8 = $sssvslot1a;
		$ssslot9 = $sssvslot1a;
		$ssslot10 = $sssvslot1a;
		$ssslot11 = $sssvslot1a;
		$ssslot12 = $sssvslot1a;
		$ssslot13 = $sssvslot1a;
		$ssslot14 = $sssvslot1a;
	}
}

sub ssreel2a {
	$ssreel = 5;
	if ($ssreelspin >= 2) {
		$ssslot1 = 'spining';
		$ssslot2 = 'spining';
		$ssslot3 = 'spining';
		$ssslot4 = 'spining';
		$ssslot5 = 'spining';
		$ssslot6 = 'spining';
		$ssslot7 = 'spining';
		$ssslot8 = 'spining';
		$ssslot9 = 'spining';
		$ssslot10 = 'spining';
		$ssslot11 = 'spining';
		$ssslot12 = 'spining';
		$ssslot13 = 'spining';
		$ssslot14 = 'spining';
	} elsif ($ssmisalign2 == 1) {
		$ssslot1 = 'misaliga';
		$ssslot2 = 'misaliga';
		$ssslot3 = 'misaliga';
		$ssslot4 = 'misaliga';
		$ssslot5 = 'misaliga';
		$ssslot6 = 'misaliga';
		$ssslot7 = 'misaliga';
		$ssslot8 = 'misaliga';
		$ssslot9 = 'misaliga';
		$ssslot10 = 'misaliga';
		$ssslot11 = 'misaliga';
		$ssslot12 = 'misaliga';
		$ssslot13 = 'misaliga';
		$ssslot14 = 'misaliga';
		$ssslotmis1 = $sssvslot2;
		$ssslotmis2 = $sssvslot2;
		$ssslotmis3 = $sssvslot2;
		$ssslotmis4 = $sssvslot2;
		$ssslotmis5 = $sssvslot2;
		$ssslotmis6 = $sssvslot2;
		$ssslotmis7 = $sssvslot2;
		$ssslotmis8 = $sssvslot2;
		$ssslotmis9 = $sssvslot2;
		$ssslotmis10 = $sssvslot2;
		$ssslotmis11 = $sssvslot2;
		$ssslotmis12 = $sssvslot2;
		$ssslotmis13 = $sssvslot2;
		$ssslotmis14 = $sssvslot2;
	} else {
		$ssslot1 = $sssvslot2a;
		$ssslot2 = $sssvslot2a;
		$ssslot3 = $sssvslot2a;
		$ssslot4 = $sssvslot2a;
		$ssslot5 = $sssvslot2a;
		$ssslot6 = $sssvslot2a;
		$ssslot7 = $sssvslot2a;
		$ssslot8 = $sssvslot2a;
		$ssslot9 = $sssvslot2a;
		$ssslot10 = $sssvslot2a;
		$ssslot11 = $sssvslot2a;
		$ssslot12 = $sssvslot2a;
		$ssslot13 = $sssvslot2a;
		$ssslot14 = $sssvslot2a;
	}
}

sub ssreel3a {
	$ssreel = 6;
	if ($ssreelspin >= 1) {
		$ssslot1 = 'spining';
		$ssslot2 = 'spining';
		$ssslot3 = 'spining';
		$ssslot4 = 'spining';
		$ssslot5 = 'spining';
		$ssslot6 = 'spining';
		$ssslot7 = 'spining';
		$ssslot8 = 'spining';
		$ssslot9 = 'spining';
		$ssslot10 = 'spining';
		$ssslot11 = 'spining';
		$ssslot12 = 'spining';
		$ssslot13 = 'spining';
		$ssslot14 = 'spining';
	} elsif ($ssmisalign3 == 1) {
		$ssslot1 = 'misaliga';
		$ssslot2 = 'misaliga';
		$ssslot3 = 'misaliga';
		$ssslot4 = 'misaliga';
		$ssslot5 = 'misaliga';
		$ssslot6 = 'misaliga';
		$ssslot7 = 'misaliga';
		$ssslot8 = 'misaliga';
		$ssslot9 = 'misaliga';
		$ssslot10 = 'misaliga';
		$ssslot11 = 'misaliga';
		$ssslot12 = 'misaliga';
		$ssslot13 = 'misaliga';
		$ssslot14 = 'misaliga';
		$ssslotmis1 = $sssvslot3;
		$ssslotmis2 = $sssvslot3;
		$ssslotmis3 = $sssvslot3;
		$ssslotmis4 = $sssvslot3;
		$ssslotmis5 = $sssvslot3;
		$ssslotmis6 = $sssvslot3;
		$ssslotmis7 = $sssvslot3;
		$ssslotmis8 = $sssvslot3;
		$ssslotmis9 = $sssvslot3;
		$ssslotmis10 = $sssvslot3;
		$ssslotmis11 = $sssvslot3;
		$ssslotmis12 = $sssvslot3;
		$ssslotmis13 = $sssvslot3;
		$ssslotmis14 = $sssvslot3;
	} else {
		$ssslot1 = $sssvslot3a;
		$ssslot2 = $sssvslot3a;
		$ssslot3 = $sssvslot3a;
		$ssslot4 = $sssvslot3a;
		$ssslot5 = $sssvslot3a;
		$ssslot6 = $sssvslot3a;
		$ssslot7 = $sssvslot3a;
		$ssslot8 = $sssvslot3a;
		$ssslot9 = $sssvslot3a;
		$ssslot10 = $sssvslot3a;
		$ssslot11 = $sssvslot3a;
		$ssslot12 = $sssvslot3a;
		$ssslot13 = $sssvslot3a;
		$ssslot14 = $sssvslot3a;
	}
}

sub sscolorr1 {
	$sscolor1 = $ssr1colora;
	$sscolor2 = $ssr1colorb;
}

sub sscolorr2 {
	$sscolor1 = $ssr2colora;
	$sscolor2 = $ssr2colorb;
}

sub sscolorr3 {
	$sscolor1 = $ssr3colora;
	$sscolor2 = $ssr3colorb;
}

sub sscolorr1m {
	if ($ssmisalign1 == 1) {
	$sscolor1 = $ssr1colorab;
	$sscolor2 = $ssr1colorbb;
	} else {
	$sscolor1 = $ssr1colora;
	$sscolor2 = $ssr1colorb;
	}
}

sub sscolorr2m {
	if ($ssmisalign2 == 1) {
	$sscolor1 = $ssr2colorab;
	$sscolor2 = $ssr2colorbb;
	} else {
	$sscolor1 = $ssr2colora;
	$sscolor2 = $ssr2colorb;
	}
}

sub sscolorr3m {
	if ($ssmisalign3 == 1) {
	$sscolor1 = $ssr3colorab;
	$sscolor2 = $ssr3colorbb;
	} else {
	$sscolor1 = $ssr3colora;
	$sscolor2 = $ssr3colorb;
	}
}

sub sscolorr1b {
	$sscolor1 = $ssr1colorab;
	$sscolor2 = $ssr1colorbb;
}

sub sscolorr2b {
	$sscolor1 = $ssr2colorab;
	$sscolor2 = $ssr2colorbb;
}

sub sscolorr3b {
	$sscolor1 = $ssr3colorab;
	$sscolor2 = $ssr3colorbb;
}

sub sscolorr1a {
	if ($ssmisalign1 == 1) {
	$sscolor1 = $ssr1colora;
	$sscolor2 = $ssr1colorb;
	} else {
	$sscolor1 = $ssr1coloraa;
	$sscolor2 = $ssr1colorba;
	}
}

sub sscolorr2a {
	if ($ssmisalign2 == 1) {
	$sscolor1 = $ssr2colora;
	$sscolor2 = $ssr2colorb;
	} else {
	$sscolor1 = $ssr2coloraa;
	$sscolor2 = $ssr2colorba;
	}
}

sub sscolorr3a {
	if ($ssmisalign3 == 1) {
	$sscolor1 = $ssr3colora;
	$sscolor2 = $ssr3colorb;
	} else {
	$sscolor1 = $ssr3coloraa;
	$sscolor2 = $ssr3colorba;
	}
}



sub ssmida1 {
	print colored('| ',"$boldred on_$bgcred");
}

sub ssmidb1 {
	print colored('LINE',"$boldwhite on_$bgcgreen");
}

sub ssmida0 {
	print colored('|',"$boldblue on_$bgcblue");
	print colored('   |',"$boldred on_$bgcred");
}

sub ssmida02 {
	print colored('|',"$boldblue on_$bgcblue");
	print colored('[X2>',"$sspx2 on_$bgcgreen");
}

sub ssmida03 {
	print colored('|',"$boldblue on_$bgcblue");
	print colored('[X3>',"$sspx3 on_$bgcgreen");
}

sub ssmida12 {
	print colored('<2X]',"$sspx2 on_$bgcgreen");
}

sub ssmida13 {
	print colored('<3X]',"$sspx3 on_$bgcgreen");
}

sub ssmida2 {
	print colored('-',"$sspx2 on_$bgcgreen");
}

sub ssmida3 {
	print colored('-',"$sspx3 on_$bgcgreen");
}

sub ssmidb0 {
	print colored('|',"$boldblue on_$bgcblue");
	print colored('PAYL',"$boldwhite on_$bgcgreen");
}

sub ssmida {
	print colored('|',"$boldred on_$bgcred");
}

sub ssmidb {
	print colored('L',"$boldwhite on_$bgcgreen");
}






sub ss13 {
	if ($ssslot1 != 11) {
		ssslot13();
	} else {
		ssslotm2();
	}
}

sub ss12 {
	if ($ssslot1 != 11) {
		ssslot12();
	} else {
		ssslotm3();
	}
}

sub ss11 {
	if ($ssslot1 != 11) {
		ssslot11();
	} else {
		ssslotm4();
	}
}

sub ss10 {
	if ($ssslot1 != 11) {
		ssslot10();
	} else {
		ssslotm5();
	}
}

sub ss1 {
	if ($ssslot1 != 11) {
		ssslot1();
	} else {
		ssslotm2();
	}
}

sub ss2 {
	if ($ssslot1 != 11) {
		ssslot2();
	} else {
		ssslotm3();
	}
}

sub ss3 {
	if ($ssslot1 != 11) {
		ssslot3();
	} else {
		ssslotm4();
	}
}

sub ss4 {
	if ($ssslot1 != 11) {
		ssslot10();
	} else {
		ssslotm5();
	}
}

sub ssmainscreen {
	print colored('/------------------------------------------------------------------------------\\',"$boldblue on_$bgcblue"); print"\n";
	print colored('|',"$boldblue on_$bgcblue"); print colored('   \\------------------|------------------|------------------/ ',"$boldred on_$bgcred"); print colored(' 3P PROGRESSIVE ',"$boldblue on_$bgcblue"); print colored('|',"$boldblue on_$bgcblue"); print"\n";
	ssmida0(); ssreel1a(); sscolorr1a(); sep; ssslot10(); sep; ssmida(); ssreel2a(); sscolorr2a(); sep; ssslot10(); sep; ssmida(); ssreel3a(); sscolorr3a(); sep; ssslot10(); sep; ssmida1(); print colored('JKPT',"$boldblue on_$bgcblue"); ssprojkpot(); print colored('|',"$boldblue on_$bgcblue");print"\n";
	ssmida0(); ssreel1a(); sscolorr1a(); sep; ssslot11(); sep; ssmida(); ssreel2a(); sscolorr2a(); sep; ssslot11(); sep; ssmida(); ssreel3a(); sscolorr3a(); sep; ssslot11(); sep; ssmida1(); if ($esegpenguinhrs != 1) { print colored('  * SEVENS',"$boldcyan on_$bgcblue"); print colored(' coin^',"$boldblue on_$bgcblue"); } else { print colored('   * PENGUINS   ',"$boldcyan on_$bgcblue"); } print colored('|',"$boldblue on_$bgcblue"); print"\n";
	ssmida02(); ssreel1a(); sscolorr1a(); sep; ssslot12(); sep; ssmida2(); ssreel2a(); sscolorr2a(); sep; ssslot12(); sep; ssmida2(); ssreel3a(); sscolorr3a(); sep; ssslot12(); sep; ssmida12(); if ($esegpenguinhrs != 1) { print colored('7',"$boldblack on_$bgcwhite"); print colored(' 7',"$magenta on_$bgcwhite"); print colored(' 7',"$boldblack on_$bgcwhite"); } else { print colored('T',"$boldblack on_$bgcwhite"); print colored(' U',"$magenta on_$bgcwhite"); print colored(' X',"$boldblack on_$bgcwhite"); } print colored('= 500000 ',"$boldwhite on_$bgcwhite"); print colored('|',"$boldblue on_$bgcblue"); print"\n";
	ssmida0(); ssreel1a(); sscolorr1a(); sep; ssslot13(); sep; ssmida(); ssreel2a(); sscolorr2a(); sep; ssslot13(); sep; ssmida(); ssreel3a(); sscolorr3a(); sep; ssslot13(); sep; ssmida1(); print colored(' OR PROGRESSIVE ',"$boldwhite on_$bgcwhite"); print colored('|',"$boldblue on_$bgcblue");  print"\n";

	ssmida0(); ssreel1(); sscolorr1(); sep; ssslotm1(); sep; ssmida(); ssreel2(); sscolorr2(); sep; ssslotm1(); sep; ssmida(); ssreel3(); sscolorr3(); sep; ssslotm1(); sep; ssmida1(); print colored('  IF 3P CENTER  ',"$boldwhite on_$bgcwhite"); print colored('|',"$boldblue on_$bgcblue"); print"\n";
	ssmida0(); ssreel1(); sscolorr1(); sep; ssslot1(); sep; ssmida(); ssreel2(); sscolorr2(); sep; ssslot1(); sep; ssmida(); ssreel3(); sscolorr3(); sep; ssslot1(); sep; ssmida1(); if ($esegpenguinhrs != 1) { print colored(' 7 7 7',"$boldblack on_$bgcwhite"); } else { print colored(' T U X',"$boldblack on_$bgcwhite"); } print colored(' = 12000  ',"$boldwhite on_$bgcwhite");  print colored('|',"$boldblue on_$bgcblue"); print"\n";
	ssmida0(); ssreel1(); sscolorr1(); sep; ssslot2(); sep; ssmida(); ssreel2(); sscolorr2(); sep; ssslot2(); sep; ssmida(); ssreel3(); sscolorr3(); sep; ssslot2(); sep; ssmida1(); if ($esegpenguinhrs != 1) { print colored(' 7',"$magenta on_$bgcwhite"); print colored(' 7',"$boldblack on_$bgcwhite"); print colored(' 7',"$magenta on_$bgcwhite"); } else { print colored(' T',"$magenta on_$bgcwhite"); print colored(' U',"$boldblack on_$bgcwhite"); print colored(' X',"$magenta on_$bgcwhite"); } print colored(' = 10000  ',"$boldwhite on_$bgcwhite"); print colored('|',"$boldblue on_$bgcblue"); print"\n";
	ssmida0(); ssreel1(); sscolorr1(); sep; ssslot3(); sep; ssmida(); ssreel2(); sscolorr2(); sep; ssslot3(); sep; ssmida(); ssreel3(); sscolorr3(); sep; ssslot3(); sep; ssmida1(); if ($esegpenguinhrs != 1) { print colored(' 7 7 7',"$magenta on_$bgcwhite"); } else { print colored(' T U X',"$magenta on_$bgcwhite"); } print colored(' = 8000   ',"$boldwhite on_$bgcwhite");  print colored('|',"$boldblue on_$bgcblue");print"\n";
	ssmida0(); ssreel1(); sscolorr1(); sep; ssslot4(); sep; ssmida(); ssreel2(); sscolorr2(); sep; ssslot4(); sep; ssmida(); ssreel3(); sscolorr3(); sep; ssslot4(); sep; ssmida1(); if ($esegpenguinhrs != 1) { print colored(' 7 7 7',"$green on_$bgcwhite"); } else { print colored(' T U X',"$green on_$bgcwhite"); } print colored(' = 6000   ',"$boldwhite on_$bgcwhite"); print colored('|',"$boldblue on_$bgcblue"); print"\n";
	ssmida0(); ssreel1(); sscolorr1(); sep; ssslot5(); sep; ssmida(); ssreel2(); sscolorr2(); sep; ssslot5(); sep; ssmida(); ssreel3(); sscolorr3(); sep; ssslot5(); sep; ssmida1(); if ($esegpenguinhrs != 1) { print colored(' 7',"$cyan on_$bgcwhite"); print colored(' 7',"$green on_$bgcwhite"); print colored(' 7',"$cyan on_$bgcwhite"); } else { print colored(' T',"$cyan on_$bgcwhite"); print colored(' U',"$green on_$bgcwhite"); print colored(' X',"$cyan on_$bgcwhite"); } print colored(' = 4000   ',"$boldwhite on_$bgcwhite"); print colored('|',"$boldblue on_$bgcblue");print"\n";
	ssmida0(); ssreel1(); sscolorr1(); sep; ssslot6(); sep; ssmida(); ssreel2(); sscolorr2(); sep; ssslot6(); sep; ssmida(); ssreel3(); sscolorr3(); sep; ssslot6(); sep; ssmida1(); if ($esegpenguinhrs != 1) { print colored(' 7 7 7',"$cyan on_$bgcwhite"); } else { print colored(' T U X',"$cyan on_$bgcwhite"); } print colored(' = 2000   ',"$boldwhite on_$bgcwhite"); print colored('|',"$boldblue on_$bgcblue"); print"\n";
	ssmidb0(); ssreel1(); sscolorr1(); ssslot7(); ssmidb(); ssreel2(); sscolorr2(); ssslot7(); ssmidb(); ssreel3(); sscolorr3(); ssslot7(); ssmidb1(); if ($esegpenguinhrs != 1) { print colored('STANDARDSEVENS',"$cyan on_$bgcblue"); } else { print colored('STANDARDPENGUI',"$cyan on_$bgcblue"); } print colored('|',"$boldblue on_$bgcblue");print"\n";
	ssmida0(); ssreel1(); sscolorr1m(); sep; ssslot8(); sep; ssmida(); ssreel2(); sscolorr2m(); sep; ssslot8(); sep; ssmida(); ssreel3(); sscolorr3m(); sep; ssslot8(); sep; ssmida1(); if ($esegpenguinhrs != 1) { print colored(' 7 7 7',"$boldmagenta on_$bgcwhite"); } else { print colored(' T U X',"$boldmagenta on_$bgcwhite"); } print colored(' = 700    ',"$boldwhite on_$bgcwhite"); print colored('|',"$boldblue on_$bgcblue");print"\n";
	ssmida0(); ssreel1(); sscolorr1m(); sep; ssslot9(); sep; ssmida(); ssreel2(); sscolorr2m(); sep; ssslot9(); sep; ssmida(); ssreel3(); sscolorr3m(); sep; ssslot9(); sep; ssmida1(); if ($esegpenguinhrs != 1) { print colored(' 7 7 7',"$boldgreen on_$bgcwhite"); } else { print colored(' T U X',"$boldgreen on_$bgcwhite"); } print colored(' = 400    ',"$boldwhite on_$bgcwhite"); print colored('|',"$boldblue on_$bgcblue");print"\n";
	ssmida0(); ssreel1(); sscolorr1m(); sep; ssslot10(); sep; ssmida(); ssreel2(); sscolorr2m(); sep; ssslot10(); sep; ssmida(); ssreel3(); sscolorr3m(); sep; ssslot10(); sep; ssmida1(); if ($esegpenguinhrs != 1) { print colored(' 7 7 7',"$blue on_$bgcwhite"); } else { print colored(' T U X',"$blue on_$bgcwhite"); } print colored(' = 250    ',"$boldwhite on_$bgcwhite"); print colored('|',"$boldblue on_$bgcblue");print"\n";
	ssmida0(); ssreel1(); sscolorr1m(); sep; ssslot11(); sep; ssmida(); ssreel2(); sscolorr2m(); sep; ssslot11(); sep; ssmida(); ssreel3(); sscolorr3m(); sep; ssslot11(); sep; ssmida1(); if ($esegpenguinhrs != 1) { print colored(' 7 7 7',"$boldyellow on_$bgcwhite"); } else { print colored(' T U X',"$boldyellow on_$bgcwhite"); } print colored(' = 130    ',"$boldwhite on_$bgcwhite"); print colored('|',"$boldblue on_$bgcblue");print"\n";
	ssmida0(); ssreel1(); sscolorr1m(); sep; ssslot12(); sep; ssmida(); ssreel2(); sscolorr2m(); sep; ssslot12(); sep; ssmida(); ssreel3(); sscolorr3m(); sep; ssslot12(); sep; ssmida1(); if ($esegpenguinhrs != 1) { print colored(' 7 7 7',"$boldwhite on_$bgcwhite"); } else { print colored(' T U X',"$boldwhite on_$bgcwhite"); } print colored(' = 80     ',"$boldwhite on_$bgcwhite"); print colored('|',"$boldblue on_$bgcblue");print"\n";
	ssmida0(); ssreel1(); sscolorr1m(); sep; ssslot13(); sep; ssmida(); ssreel2(); sscolorr2m(); sep; ssslot13(); sep; ssmida(); ssreel3(); sscolorr3m(); sep; ssslot13(); sep; ssmida1(); if ($esegpenguinhrs != 1) { print colored(' 7 7 7',"$red on_$bgcwhite"); } else { print colored(' T U X',"$red on_$bgcwhite"); } print colored(' = 20     ',"$boldwhite on_$bgcwhite"); print colored('|',"$boldblue on_$bgcblue");print"\n";
	ssmida0(); ssreel1(); sscolorr1m(); sep; ssslotp1(); sep; ssmida(); ssreel2(); sscolorr2m(); sep; ssslotp1(); sep; ssmida(); ssreel3(); sscolorr3m(); sep; ssslotp1(); sep; ssmida1(); print colored('                |',"$boldblue on_$bgcblue"); beepalrm();

	ssmida0(); ssreel1b(); sscolorr1b(); sep; ssslot1(); sep; ssmida(); ssreel2b(); sscolorr2b(); sep; ssslot1(); sep; ssmida(); ssreel3b(); sscolorr3b(); sep; ssslot1(); sep; ssmida1(); print colored('THIS SLOT PLAYS:',"$black on_$bgcwhite");print colored('|',"$boldblue on_$bgcblue"); beepalrm();
	ssmida03(); ssreel1b(); sscolorr1b(); sep; ssslot2(); sep; ssmida3(); ssreel2b(); sscolorr2b(); sep; ssslot2(); sep; ssmida3(); ssreel3b(); sscolorr3b(); sep; ssslot2(); sep; ssmida13(); print colored('5Tokn| 1Credit',"$boldblack on_$bgcwhite");print colored('|',"$boldblue on_$bgcblue"); beepalrm();
	ssmida0(); ssreel1b(); sscolorr1b(); sep; ssslot3(); sep; ssmida(); ssreel2b(); sscolorr2b(); sep; ssslot3(); sep; ssmida(); ssreel3b(); sscolorr3b(); sep; ssslot3(); sep; ssmida1(); print colored('10Tokns| 2Credit',"$boldblack on_$bgcwhite");print colored('|',"$boldblue on_$bgcblue"); beepalrm();
	ssmida0(); ssreel1b(); sscolorr1b(); sep; ssslot4(); sep; ssmida(); ssreel2b(); sscolorr2b(); sep; ssslot4(); sep; ssmida(); ssreel3b(); sscolorr3b(); sep; ssslot4(); sep; ssmida1(); print colored('15Tokns| 3Credit',"$boldblack on_$bgcwhite");print colored('|',"$boldblue on_$bgcblue"); beepalrm();
	print colored('|',"$boldblue on_$bgcblue"); print colored('   /------------------|------------------|------------------\\   ',"$boldred on_$bgcred"); print colored('              ',"$boldblack on_$bgcred"); print colored('|',"$boldblue on_$bgcblue");  beepalrm();
	print colored('|',"$boldblue on_$bgcblue"); print colored(' P = Play Center    2P = Play Center+Top    C = Return to Casino',"$boldred on_$bgcred");  print colored('  HIGH ROLLER ',"$boldblack on_$bgcred"); print colored('|',"$boldblue on_$bgcblue");  beepalrm();
	print colored('|',"$boldblue on_$bgcblue"); print colored('     3P = Play Center+Top+Bottom+Diagonals    EXIT = Quit       ',"$boldred on_$bgcred"); if ($esegpenguinhrs != 1) { print colored('     SEVENS   ',"$boldblack on_$bgcred"); } else { print colored('    PENGUINS  ',"$boldblack on_$bgcred"); } print colored('|',"$boldblue on_$bgcblue");  beepalrm();
	
	$beepnum = 0;
}

sub ssdisplaywin {
	print colored('|',"$boldblue on_$bgcblue");
	print colored(' WINNINGS ',"$boldyellow on_$bgcred");
	
	sep;
	if ($ssaddmoney > 9999999999) {
	print colored(sprintf("%.4e", $ssaddmoney),"$boldblack on_$bgcwhite");
	} elsif ($ssaddmoney >= 1000000000) {
	print colored("$ssaddmoney","$boldblack on_$bgcwhite");
	} elsif ($ssaddmoney >= 100000000) {
	print colored(" $ssaddmoney","$boldblack on_$bgcwhite");
	} elsif ($ssaddmoney >= 10000000) {
	print colored("  $ssaddmoney","$boldblack on_$bgcwhite");
	} elsif ($ssaddmoney >= 1000000) {
	print colored("   $ssaddmoney","$boldblack on_$bgcwhite");	
	} elsif ($ssaddmoney >= 100000) {
	print colored("    $ssaddmoney","$boldblack on_$bgcwhite");
	} elsif ($ssaddmoney >= 10000) {
	print colored("     $ssaddmoney","$boldblack on_$bgcwhite");
	} elsif ($ssaddmoney >= 1000) {
	print colored("      $ssaddmoney","$boldblack on_$bgcwhite");
	} elsif ($ssaddmoney >= 100) {
	print colored("       $ssaddmoney","$boldblack on_$bgcwhite");
	} elsif ($ssaddmoney >= 10) {
	print colored("        $ssaddmoney","$boldblack on_$bgcwhite");
	} elsif ($ssaddmoney >= 1) {
	print colored("         $ssaddmoney","$boldblack on_$bgcwhite");
	} else {
	print colored("         $ssaddmoney","$boldblack on_$bgcwhite");
	}
	sep;

	print colored(' TOTAL FUNDS ',"$boldyellow on_$bgcred");
	
	sep;
	if ($money > 9999999999) {
	print colored(sprintf("%.4e", $money),"$boldgreen on_$bgcgreen");
	} elsif ($money >= 1000000000) {
	print colored("$money","$boldgreen on_$bgcgreen");
	} elsif ($money >= 100000000) {
	print colored(" $money","$boldgreen on_$bgcgreen");
	} elsif ($money >= 10000000) {
	print colored("  $money","$boldgreen on_$bgcgreen");
	} elsif ($money >= 1000000) {
	print colored("   $money","$boldgreen on_$bgcgreen");
	} elsif ($money >= 100000) {
	print colored("    $money","$boldgreen on_$bgcgreen");
	} elsif ($money >= 10000) {
	print colored("     $money","$boldgreen on_$bgcgreen");
	} elsif ($money >= 1000) {
	print colored("      $money","$boldgreen on_$bgcgreen");
	} elsif ($money >= 100) {
	print colored("       $money","$boldgreen on_$bgcgreen");
	} elsif ($money >= 10) {
	print colored("        $money","$boldgreen on_$bgcgreen");
	} elsif ($money >= 1) {
	print colored("         $money","$boldgreen on_$bgcgreen");
	} else {
	print colored("         $money","$boldgreen on_$bgcgreen");
	}
	sep;
							    #
	print colored(' INSERT TOKENS ',"$boldyellow on_$bgcred");	
	sep; 
	print colored(' ---------- ',"$black on_$bgcyellow");
	sep; 
	print colored('   ',"$boldblue on_$bgcred");
	print colored('|----/',"$boldblue on_$bgcblue");
	print"\n";
	print colored('\\-------------------------------------------------------------------------/',"$boldblue on_$bgcblue");
	STDOUT->flush();
}

sub ssprojkpot {
	$jkclr = "$red";
	sep;
	if ($projkpot > 999999999999) {
	print colored(sprintf("%.6e", $projkpot),"bold $jkclr on_$bgcred");
	} elsif ($projkpot >= 100000000000) {
	print colored("$projkpot","bold $jkclr on_$bgcred");
	} elsif ($projkpot >= 10000000000) {
	print colored(" $projkpot","bold $jkclr on_$bgcred");
	} elsif ($projkpot >= 1000000000) {
	print colored("  $projkpot","bold $jkclr on_$bgcred");
	} elsif ($projkpot >= 100000000) {
	print colored("   $projkpot","bold $jkclr on_$bgcred");
	} elsif ($projkpot >= 10000000) {
	print colored("    $projkpot","bold $jkclr on_$bgcred");
	} elsif ($projkpot >= 1000000) {
	print colored("     $projkpot","bold $jkclr on_$bgcred");
	} elsif ($projkpot >= 100000) {
	print colored("      $projkpot","bold $jkclr on_$bgcred");
	} elsif ($projkpot >= 10000) {
	print colored("       $projkpot","bold $jkclr on_$bgcred");
	} elsif ($projkpot >= 1000) {
	print colored("        $projkpot","bold $jkclr on_$bgcred");
	} elsif ($projkpot >= 100) {
	print colored("         $projkpot","bold $jkclr on_$bgcred");
	} elsif ($projkpot >= 10) {
	print colored("          $projkpot","bold $jkclr on_$bgcred");
	} elsif ($projkpot >= 1) {
	print colored("           $projkpot","bold $jkclr on_$bgcred");
	} else {
	print colored("           $projkpot","bold $jkclr on_$bgcred");
	}
	sep; 	
}


################################################################################################################################
## GENRE: Slot Mahine
## NAME: Twilight Mine
## AUTHOR: MikeeUSA

sub ngemmain {
	ngemresetvars();
	ngemspinreel();
	ngemreeltrans();
	
	if ($animate == 1) {
		$ngemreelspin = 5;
		ngemtopprint();
		ngemmainscreen();
		smallpause();
		newlines();
		
		$ngemreelspin = 4;
		ngemtopprint();
		ngemmainscreen();
		smallpause();
		newlines();
	
		$ngemreelspin = 3;
		ngemtopprint();
		ngemmainscreen();
		smallpause();
		newlines();
	
		if ($ngemplaylevel >= 2) {
		$ngemreelspin = 2;
		ngemtopprint();
		ngemmainscreen();
		smallpause();
		newlines();
		}
		
		if ($ngemplaylevel >= 3) {
		$ngemreelspin = 1;
		ngemtopprint();
		ngemmainscreen();
		smallpause();
		newlines();
		}			
	}
	
	$ngemreelspin = 0;
	ngemtopprint();
	$ngemx12 = $ngemsvslot1.$ngemsvslot2;
	$ngemx23 = $ngemsvslot2.$ngemsvslot3;
	$ngemx34 = $ngemsvslot3.$ngemsvslot4;
	$ngemx45 = $ngemsvslot4.$ngemsvslot5;
	$ngemx123 = $ngemsvslot1.$ngemsvslot2.$ngemsvslot3;
	$ngemx234 = $ngemsvslot2.$ngemsvslot3.$ngemsvslot4;
	$ngemx345 = $ngemsvslot3.$ngemsvslot4.$ngemsvslot5;
	$ngemx1234 = $ngemsvslot1.$ngemsvslot2.$ngemsvslot3.$ngemsvslot4;
	$ngemx2345 = $ngemsvslot2.$ngemsvslot3.$ngemsvslot4.$ngemsvslot5;
	$ngemx12345 = $ngemsvslot1.$ngemsvslot2.$ngemsvslot3.$ngemsvslot4.$ngemsvslot5;
	ngemangemmoney();
	ngemfundcalc();
	ngemmainscreen();
	ptracker();
	ngemstartinfo();	
}

sub ngemmain2 {
	$ngemplaylevel = 0;
	ngemresetvars();
	ngemreeltrans();
	ngemtopprint();
	$ngemx123 = ' '; #keep, a reset to null type job... well not quite null.
	$ngemx12 = ' ';
	$ngemx23 = ' ';
	if ($ngemplaylevel >= 2) {
	$ngemx234 = ' ';
	$ngemx1234 = ' ';
	$ngemx34 = ' ';
	}
	if ($ngemplaylevel >= 3) {
	$ngemx345 = ' ';
	$ngemx2345 = ' ';
	$ngemx12345 = ' ';
	$ngemx45 = ' ';
	}
	ngemmainscreen();
	ngemstartinfo();	
}

sub ngemresetvars {
	$ngemreelspin = 0;
}

sub ngemstartinfo {
	tokeneval();
	$ngemstartinfo = <STDIN>;
	chomp($ngemstartinfo);
	
	if (($ngemstartinfo eq 'a') or ($ngemstartinfo eq 'A')) {
		$ngemstartinfo = $ngemagaincmd;
	} elsif  (($ngemstartinfo eq 'p') or ($ngemstartinfo eq 'P') or ($ngemstartinfo eq '1p') or ($ngemstartinfo eq '1P')
		or ($ngemstartinfo eq '2p') or ($ngemstartinfo eq '2P') or ($ngemstartinfo eq '3p') or ($ngemstartinfo eq '3P')) {
		$ngemagaincmd = $ngemstartinfo;
	} else {
		#Do Nothing		
	}

	if (($ngemstartinfo eq 'p') or ($ngemstartinfo eq 'P') or ($ngemstartinfo eq '1P') or ($ngemstartinfo eq '1p')) {
		if ($money >= (2 * $coin)) {
			$ngemplaylevel = 1;
			$money = $money - (2 * $coin);
			$moneyexp = $moneyexp + (2 * $coin);
			$ngemstmc2 = $ngemstmc2 + (2 * $coin);
			$spins = $spins + 1;
			$ngemstspins = $ngemstspins + 1;
			if ($proadd == 1) {
				$projkpot = $projkpot + (2 * $coin);
				$proadd = 0;
			} else {
				$proadd = 1;
			}
			newlines();
			ngemmain();
		} else {
			newlines();
			ngemmain2();		
		}
	} elsif (($ngemstartinfo eq '2p') or ($ngemstartinfo eq '2P')) {
		if ($money >= (4 * $coin)) {
			$ngemplaylevel = 2;
			$money = $money - (4 * $coin);
			$moneyexp = $moneyexp + (4 * $coin);
			$ngemstmc2 = $ngemstmc2 + (4 * $coin);
			$spins = $spins + 1;
			$ngemstspins = $ngemstspins + 1;
			if ($proadd == 1) {
				$projkpot = $projkpot + (4 * $coin);
				$proadd = 0;
			} else {
				$proadd = 1;
			}
			newlines();
			ngemmain();
		} else {
			newlines();
			ngemmain2();		
		}
	} elsif (($ngemstartinfo eq '3p') or ($ngemstartinfo eq '3P')) {
		if ($money >= (6 * $coin)) {
			$ngemplaylevel = 3;
			$money = $money - (6 * $coin);
			$moneyexp = $moneyexp + (6 * $coin);
			$ngemstmc2 = $ngemstmc2 + (6 * $coin);
			$spins = $spins + 1;
			$ngemstspins = $ngemstspins + 1;
			if ($proadd == 1) {
				$projkpot = $projkpot + (6 * $coin);
				$proadd = 0;
			} else {
				$proadd = 1;
			}
			newlines();
			ngemmain();
		} else {
			newlines();
			ngemmain2();		
		}				
	} elsif (($ngemstartinfo eq 'exit') or ($ngemstartinfo eq 'EXIT') or ($ngemstartinfo eq 'quit') or ($ngemstartinfo eq 'QUIT')) {
		exitgame();
	} elsif (($ngemstartinfo eq 'c') or ($ngemstartinfo eq 'C')) {
		return;
	} else {
		newlines();
		ngemmain2();
	}

}

sub ngemfundcalc {
	$money = $money + $ngemangemmoney;
	$ngemstmc = $ngemstmc + $ngemangemmoney;
}

sub ngemslot1emr2  { if ($ngemsymbol != 1) { 
				print colored('      /|',"bold $ngemcolor on_$bgcblack"); print colored('\     ',"$ngemcolor on_$bgcblack");
			} else { 
				print colored(' ___________  ',"bold $ngemcolor on_$bgcblack");
			}
		}
sub ngemslot1emr3  { if ($ngemsymbol != 1) { 
				print colored('     /*|',"bold $ngemcolor on_$bgcblack"); print colored('*\    ',"$ngemcolor on_$bgcblack"); 
			} else { 
				print colored('/_____|_____\\ ',"bold $ngemcolor on_$bgcblack");
			}
		}
sub ngemslot1emr4  { if ($ngemsymbol != 1) { 
				print colored('    /*/',"bold $ngemcolor on_$bgcblack"); print colored('0\ \   ',"$ngemcolor on_$bgcblack"); 
			} else { 
				print colored('\\**  *',"bold $ngemcolor on_$bgcblack"); print colored('| 0  0/ ',"$ngemcolor on_$bgcblack");
			}
		}
sub ngemslot1emr5  { if ($ngemsymbol != 1) { 
				print colored('   /*/',"bold $ngemcolor on_$bgcblack"); print colored('0 0\*\  ',"$ngemcolor on_$bgcblack"); 
			} else { 
				print colored(' \\ * *',"bold $ngemcolor on_$bgcblack"); print colored('|  00/  ',"$ngemcolor on_$bgcblack");
			}
		}
sub ngemslot1emr6  { if ($ngemsymbol != 1) { 
				print colored('  /_/',"bold $ngemcolor on_$bgcblack"); print colored('0 000\_\ ',"$ngemcolor on_$bgcblack"); 
			} else { 
				print colored('  \\ * ',"bold $ngemcolor on_$bgcblack"); print colored('|0  /   ',"$ngemcolor on_$bgcblack");
			}
		}
sub ngemslot1emr7  { if ($ngemsymbol != 1) { 
				print colored('  \*\000 0/*/ ',"$ngemcolor on_$bgcblack"); 
			} else { 
				print colored('   \\ *',"bold $ngemcolor on_$bgcblack"); print colored('| 0/    ',"$ngemcolor on_$bgcblack");
			}
		}
sub ngemslot1emr8  { if ($ngemsymbol != 1) { 
				print colored('   \ \ 00/*/  ',"$ngemcolor on_$bgcblack"); 
			} else { 
				print colored('    \\*',"bold $ngemcolor on_$bgcblack"); print colored('| /     ',"$ngemcolor on_$bgcblack");
			}
		}
sub ngemslot1emr9  { if ($ngemsymbol != 1) { 
				print colored('    \*\0/ /   ',"$ngemcolor on_$bgcblack"); 
			} else { 
				print colored('     \\',"bold $ngemcolor on_$bgcblack"); print colored('|/      ',"$ngemcolor on_$bgcblack");
			}
		}
sub ngemslot1emr10 { if ($ngemsymbol != 1) { 
				print colored('     \ |*/    ',"$ngemcolor on_$bgcblack"); 
			} else { 
				print colored('              ',"$ngemcolor on_$bgcblack");
			}
		}
sub ngemslot1emr11 { if ($ngemsymbol != 1) { 
				print colored('      \|/     ',"$ngemcolor on_$bgcblack"); 
			} else { 
				print colored('              ',"$ngemcolor on_$bgcblack");
			}
		}


sub ngemslotwhite { print colored('              ',"$ngemcolor on_$bgcblack"); }

sub ngemslotspining { print colored('||||||||||||||',"$boldblack on_$bgcblack"); }


sub ngem45init {
	$ngemslotsymbol4 = int(rand(60));
	$ngemslotsymbol5 = int(rand(60));
}

sub ngemspinreel {
	$ngemslotsymbol1 = int(rand(60));
	$ngemslotsymbol2 = int(rand(60));
	$ngemslotsymbol3 = int(rand(60));
	
	if ($ngemplaylevel >= 2) { 
		$ngemslotsymbol4 = int(rand(60));
	}
	
	if ($ngemplaylevel >= 3) {
		$ngemslotsymbol5 = int(rand(60));
	}
}

sub ngemreeltrans {
	if ($ngemslotsymbol1 <= 12) {
		$ngemsvslot1 = 7;
		$ngemr1color = "$cyan";
	} elsif ($ngemslotsymbol1 <= 22) {
		$ngemsvslot1 = 6;
		$ngemr1color = "$magenta";
	} elsif ($ngemslotsymbol1 <= 30) {
		$ngemsvslot1 = 5;
		$ngemr1color = "$blue";
	} elsif ($ngemslotsymbol1 <= 36) {
		$ngemsvslot1 = 4;
		$ngemr1color = "$yellow";
	} elsif ($ngemslotsymbol1 <= 40) {
		$ngemsvslot1 = 3;
		$ngemr1color = "$red";
	} elsif ($ngemslotsymbol1 <= 42) {
		$ngemsvslot1 = 2;
		$ngemr1color = "$white";
	} elsif ($ngemslotsymbol1 <= 43) {
		$ngemsvslot1 = 1;
		$ngemr1color = "$green";
	} elsif ($ngemslotsymbol1 <= 46) {
		$ngemsvslot1 = 8;
		$ngemr1color = "$white";
	} elsif ($ngemslotsymbol1 <= 50) {
		$ngemsvslot1 = 9;
		$ngemr1color = "$white";
	} elsif ($ngemslotsymbol1 <= 54) {
		$ngemsvslot1 = 10;
		$ngemr1color = "$white";
	} elsif ($ngemslotsymbol1 <= 59) {
		$ngemsvslot1 = 11;
		$ngemr1color = "$white";				
	} else {
		$ngemsvslot1 = 0;
		$ngemr1color = "$white";
	}
	
	if ($ngemslotsymbol2 <= 12) {
		$ngemsvslot2 = 7;
		$ngemr2color = "$cyan";
	} elsif ($ngemslotsymbol2 <= 22) {
		$ngemsvslot2 = 6;
		$ngemr2color = "$magenta";
	} elsif ($ngemslotsymbol2 <= 30) {
		$ngemsvslot2 = 5;
		$ngemr2color = "$blue";
	} elsif ($ngemslotsymbol2 <= 36) {
		$ngemsvslot2 = 4;
		$ngemr2color = "$yellow";
	} elsif ($ngemslotsymbol2 <= 40) {
		$ngemsvslot2 = 3;
		$ngemr2color = "$red";
	} elsif ($ngemslotsymbol2 <= 42) {
		$ngemsvslot2 = 2;
		$ngemr2color = "$white";
	} elsif ($ngemslotsymbol2 <= 43) {
		$ngemsvslot2 = 1;
		$ngemr2color = "$green";
	} elsif ($ngemslotsymbol2 <= 46) {
		$ngemsvslot2 = 8;
		$ngemr2color = "$white";
	} elsif ($ngemslotsymbol2 <= 50) {
		$ngemsvslot2 = 9;
		$ngemr2color = "$white";
	} elsif ($ngemslotsymbol2 <= 54) {
		$ngemsvslot2 = 10;
		$ngemr2color = "$white";
	} elsif ($ngemslotsymbol2 <= 59) {
		$ngemsvslot2 = 11;
		$ngemr2color = "$white";	
	} else {
		$ngemsvslot2 = 0;
		$ngemr2color = "$white";
	}
	
	if ($ngemslotsymbol3 <= 12) {
		$ngemsvslot3 = 7;
		$ngemr3color = "$cyan";
	} elsif ($ngemslotsymbol3 <= 22) {
		$ngemsvslot3 = 6;
		$ngemr3color = "$magenta";
	} elsif ($ngemslotsymbol3 <= 30) {
		$ngemsvslot3 = 5;
		$ngemr3color = "$blue";
	} elsif ($ngemslotsymbol3 <= 36) {
		$ngemsvslot3 = 4;
		$ngemr3color = "$yellow";
	} elsif ($ngemslotsymbol3 <= 40) {
		$ngemsvslot3 = 3;
		$ngemr3color = "$red";
	} elsif ($ngemslotsymbol3 <= 42) {
		$ngemsvslot3 = 2;
		$ngemr3color = "$white";
	} elsif ($ngemslotsymbol3 <= 43) {
		$ngemsvslot3 = 1;
		$ngemr3color = "$green";
	} elsif ($ngemslotsymbol3 <= 46) {
		$ngemsvslot3 = 8;
		$ngemr3color = "$white";
	} elsif ($ngemslotsymbol3 <= 50) {
		$ngemsvslot3 = 9;
		$ngemr3color = "$white";
	} elsif ($ngemslotsymbol3 <= 54) {
		$ngemsvslot3 = 10;
		$ngemr3color = "$white";
	} elsif ($ngemslotsymbol3 <= 59) {
		$ngemsvslot3 = 11;
		$ngemr3color = "$white";		
	} else {
		$ngemsvslot3 = 0;
		$ngemr3color = "$white";
	}		
	
	if ($ngemslotsymbol4 <= 12) {
		$ngemsvslot4 = 7;
		$ngemr4color = "$cyan";
	} elsif ($ngemslotsymbol4 <= 22) {
		$ngemsvslot4 = 6;
		$ngemr4color = "$magenta";
	} elsif ($ngemslotsymbol4 <= 30) {
		$ngemsvslot4 = 5;
		$ngemr4color = "$blue";
	} elsif ($ngemslotsymbol4 <= 36) {
		$ngemsvslot4 = 4;
		$ngemr4color = "$yellow";
	} elsif ($ngemslotsymbol4 <= 40) {
		$ngemsvslot4 = 3;
		$ngemr4color = "$red";
	} elsif ($ngemslotsymbol4 <= 42) {
		$ngemsvslot4 = 2;
		$ngemr4color = "$white";
	} elsif ($ngemslotsymbol4 <= 43) {
		$ngemsvslot4 = 1;
		$ngemr4color = "$green";
	} elsif ($ngemslotsymbol4 <= 46) {
		$ngemsvslot4 = 8;
		$ngemr4color = "$white";
	} elsif ($ngemslotsymbol4 <= 50) {
		$ngemsvslot4 = 9;
		$ngemr4color = "$white";
	} elsif ($ngemslotsymbol4 <= 54) {
		$ngemsvslot4 = 10;
		$ngemr4color = "$white";
	} elsif ($ngemslotsymbol4 <= 59) {
		$ngemsvslot4 = 11;
		$ngemr4color = "$white";	
	} else {
		$ngemsvslot4 = 0;
		$ngemr4color = "$white";
	}
	
	if ($ngemslotsymbol5 <= 12) {
		$ngemsvslot5 = 7;
		$ngemr5color = "$cyan";
	} elsif ($ngemslotsymbol5 <= 22) {
		$ngemsvslot5 = 6;
		$ngemr5color = "$magenta";
	} elsif ($ngemslotsymbol5 <= 30) {
		$ngemsvslot5 = 5;
		$ngemr5color = "$blue";
	} elsif ($ngemslotsymbol5 <= 36) {
		$ngemsvslot5 = 4;
		$ngemr5color = "$yellow";
	} elsif ($ngemslotsymbol5 <= 40) {
		$ngemsvslot5 = 3;
		$ngemr5color = "$red";
	} elsif ($ngemslotsymbol5 <= 42) {
		$ngemsvslot5 = 2;
		$ngemr5color = "$white";
	} elsif ($ngemslotsymbol5 <= 43) {
		$ngemsvslot5 = 1;
		$ngemr5color = "$green";
	} elsif ($ngemslotsymbol5 <= 46) {
		$ngemsvslot5 = 8;
		$ngemr5color = "$white";
	} elsif ($ngemslotsymbol5 <= 50) {
		$ngemsvslot5 = 9;
		$ngemr5color = "$white";
	} elsif ($ngemslotsymbol5 <= 54) {
		$ngemsvslot5 = 10;
		$ngemr5color = "$white";
	} elsif ($ngemslotsymbol5 <= 59) {
		$ngemsvslot5 = 11;
		$ngemr5color = "$white";		
	} else {
		$ngemsvslot5 = 0;
		$ngemr5color = "$white";
	}

}


					
sub ngemslot1 {
	if ($ngemslot1 eq 'spining') {
		ngemslotspining();
	} elsif ($ngemslot1 == 1) {
		ngemslot1emr2();
	} elsif ($ngemslot1 == 3) {
		ngemslot1emr2();
	} elsif ($ngemslot1 == 5) {
		ngemslot1emr2();	
	} elsif ($ngemslot1 == 7) {
		ngemslot1emr2();
	} elsif ($ngemslot1 == 8) {
		$ngemcolor = "$yellow";
		ngemslot1emr9();
	} elsif ($ngemslot1 == 9) {
		$ngemcolor = "$magenta";
		ngemslot1emr8();
	} elsif ($ngemslot1 == 10) {
		$ngemcolor = "$magenta";
		ngemslot1emr9();
	} elsif ($ngemslot1 == 11) {
		$ngemcolor = "$white";
		ngemslot1emr8();			
	} else {
		ngemslotwhite();
	}

}

sub ngemslot2 {
	if ($ngemslot2 eq 'spining') {
		ngemslotspining();
	} elsif ($ngemslot2 == 1) {
		ngemslot1emr3();
	} elsif ($ngemslot2 == 2) {
		ngemslot1emr2();	
	} elsif ($ngemslot2 == 3) {
		ngemslot1emr3();
	} elsif ($ngemslot2 == 4) {
		ngemslot1emr2();	
	} elsif ($ngemslot2 == 5) {
		ngemslot1emr3();
	} elsif ($ngemslot2 == 6) {
		ngemslot1emr2();		
	} elsif ($ngemslot2 == 7) {
		ngemslot1emr3();
	} elsif ($ngemslot2 == 8) {
		$ngemcolor = "$yellow";
		ngemslot1emr10();
	} elsif ($ngemslot2 == 9) {
		$ngemcolor = "$magenta";
		ngemslot1emr9();
	} elsif ($ngemslot2 == 10) {
		$ngemcolor = "$magenta";
		ngemslot1emr10();
	} elsif ($ngemslot2 == 11) {
		$ngemcolor = "$white";
		ngemslot1emr9();		
	} else {
		ngemslotwhite();
	}

}

sub ngemslot3 {
	if ($ngemslot3 eq 'spining') {
		ngemslotspining();
	} elsif ($ngemslot3 == 1) {
		ngemslot1emr4();
	} elsif ($ngemslot3 == 2) {
		ngemslot1emr3();	
	} elsif ($ngemslot3 == 3) {
		ngemslot1emr4();
	} elsif ($ngemslot3 == 4) {
		ngemslot1emr3();	
	} elsif ($ngemslot3 == 5) {
		ngemslot1emr4();
	} elsif ($ngemslot3 == 6) {
		ngemslot1emr3();		
	} elsif ($ngemslot3 == 7) {
		ngemslot1emr4();
	} elsif ($ngemslot3 == 8) {
		$ngemcolor = "$yellow";
		ngemslot1emr11();
	} elsif ($ngemslot3 == 9) {
		$ngemcolor = "$magenta";
		ngemslot1emr10();
	} elsif ($ngemslot3 == 10) {
		$ngemcolor = "$magenta";
		ngemslot1emr11();
	} elsif ($ngemslot3 == 11) {
		$ngemcolor = "$white";
		ngemslot1emr10();	
	} else {
		ngemslotwhite();
	}


}

sub ngemslot4 {
	if ($ngemslot4 eq 'spining') {
		ngemslotspining();
	} elsif ($ngemslot4 == 1) {
		ngemslot1emr5();
	} elsif ($ngemslot4 == 2) {
		ngemslot1emr4();	
	} elsif ($ngemslot4 == 3) {
		ngemslot1emr5();
	} elsif ($ngemslot4 == 4) {
		ngemslot1emr4();	
	} elsif ($ngemslot4 == 5) {
		ngemslot1emr5();
	} elsif ($ngemslot4 == 6) {
		ngemslot1emr4();		
	} elsif ($ngemslot4 == 7) {
		ngemslot1emr5();
	} elsif ($ngemslot4 == 9) {
		$ngemcolor = "$magenta";
		ngemslot1emr11();
	} elsif ($ngemslot4 == 11) {
		$ngemcolor = "$white";
		ngemslot1emr11();		
	} else {
		ngemslotwhite();
	}

}

sub ngemslot5 {
	if ($ngemslot5 eq 'spining') {
		ngemslotspining();
	} elsif ($ngemslot5 == 1) {
		ngemslot1emr6();
	} elsif ($ngemslot5 == 2) {
		ngemslot1emr5();	
	} elsif ($ngemslot5 == 3) {
		ngemslot1emr6();
	} elsif ($ngemslot5 == 4) {
		ngemslot1emr5();	
	} elsif ($ngemslot5 == 5) {
		ngemslot1emr6();
	} elsif ($ngemslot5 == 6) {
		ngemslot1emr5();		
	} elsif ($ngemslot5 == 7) {
		ngemslot1emr6();
	} else {
		ngemslotwhite();
	}


}

sub ngemslot6 {
	if ($ngemslot6 eq 'spining') {
		ngemslotspining();
	} elsif ($ngemslot6 == 1) {
		ngemslot1emr7();
	} elsif ($ngemslot6 == 2) {
		ngemslot1emr6();	
	} elsif ($ngemslot6 == 3) {
		ngemslot1emr7();
	} elsif ($ngemslot6 == 4) {
		ngemslot1emr6();	
	} elsif ($ngemslot6 == 5) {
		ngemslot1emr7();
	} elsif ($ngemslot6 == 6) {
		ngemslot1emr6();		
	} elsif ($ngemslot6 == 7) {
		ngemslot1emr7();
	} else {
		ngemslotwhite();
	}


}

sub ngemslot7 {
	if ($ngemslot7 eq 'spining') {
		ngemslotspining();
	} elsif ($ngemslot7 == 1) {
		ngemslot1emr8();
	} elsif ($ngemslot7 == 2) {
		ngemslot1emr7();	
	} elsif ($ngemslot7 == 3) {
		ngemslot1emr8();
	} elsif ($ngemslot7 == 4) {
		ngemslot1emr7();	
	} elsif ($ngemslot7 == 5) {
		ngemslot1emr8();
	} elsif ($ngemslot7 == 6) {
		ngemslot1emr7();		
	} elsif ($ngemslot7 == 7) {
		ngemslot1emr8();
	} else {
		ngemslotwhite();
	}

}

sub ngemslot8 {
	if ($ngemslot8 eq 'spining') {
		ngemslotspining();
	} elsif ($ngemslot8 == 1) {
		ngemslot1emr9();
	} elsif ($ngemslot8 == 2) {
		ngemslot1emr8();	
	} elsif ($ngemslot8 == 3) {
		ngemslot1emr9();
	} elsif ($ngemslot8 == 4) {
		ngemslot1emr8();	
	} elsif ($ngemslot8 == 5) {
		ngemslot1emr9();
	} elsif ($ngemslot8 == 6) {
		ngemslot1emr8();		
	} elsif ($ngemslot8 == 7) {
		ngemslot1emr9();
	} elsif ($ngemslot8 == 8) {
		$ngemcolor = "$cyan";
		ngemslot1emr2();
	} elsif ($ngemslot8 == 10) {
		$ngemcolor = "$green";
		ngemslot1emr2();
	} else {
		ngemslotwhite();
	}

}

sub ngemslot9 {
	if ($ngemslot9 eq 'spining') {
		ngemslotspining();
	} elsif ($ngemslot9 == 1) {
		ngemslot1emr10();
	} elsif ($ngemslot9 == 2) {
		ngemslot1emr9();	
	} elsif ($ngemslot9 == 3) {
		ngemslot1emr10();
	} elsif ($ngemslot9 == 4) {
		ngemslot1emr9();	
	} elsif ($ngemslot9 == 5) {
		ngemslot1emr10();
	} elsif ($ngemslot9 == 6) {
		ngemslot1emr9();		
	} elsif ($ngemslot9 == 7) {
		ngemslot1emr10();
	} elsif ($ngemslot9 == 8) {
		$ngemcolor = "$cyan";
		ngemslot1emr3();
	} elsif ($ngemslot9 == 9) {
		$ngemcolor = "$blue";
		ngemslot1emr2();
	} elsif ($ngemslot9 == 10) {
		$ngemcolor = "$green";
		ngemslot1emr3();
	} elsif ($ngemslot9 == 11) {
		$ngemcolor = "$red";
		ngemslot1emr2();		
	} else {
		ngemslotwhite();
	}


}

sub ngemslot10 {
	if ($ngemslot10 eq 'spining') {
		ngemslotspining();
	} elsif ($ngemslot10 == 1) {
		ngemslot1emr11();
	} elsif ($ngemslot10 == 2) {
		ngemslot1emr10();	
	} elsif ($ngemslot10 == 3) {
		ngemslot1emr11();
	} elsif ($ngemslot10 == 4) {
		ngemslot1emr10();	
	} elsif ($ngemslot10 == 5) {
		ngemslot1emr11();
	} elsif ($ngemslot10 == 6) {
		ngemslot1emr10();		
	} elsif ($ngemslot10 == 7) {
		ngemslot1emr11();
	} elsif ($ngemslot10 == 8) {
		$ngemcolor = "$cyan";
		ngemslot1emr4();
	} elsif ($ngemslot10 == 9) {
		$ngemcolor = "$blue";
		ngemslot1emr3();
	} elsif ($ngemslot10 == 10) {
		$ngemcolor = "$green";
		ngemslot1emr4();
	} elsif ($ngemslot10 == 11) {
		$ngemcolor = "$red";
		ngemslot1emr3();				
	} else {
		ngemslotwhite();
	}


}

sub ngemslot11 {
	if ($ngemslot11 eq 'spining') {
		ngemslotspining();
	} elsif ($ngemslot11 == 2) {
		ngemslot1emr11();	
	} elsif ($ngemslot11 == 4) {
		ngemslot1emr11();	
	} elsif ($ngemslot11 == 6) {
		ngemslot1emr11();
	} elsif ($ngemslot11 == 8) {
		$ngemcolor = "$cyan";
		ngemslot1emr5();
	} elsif ($ngemslot11 == 9) {
		$ngemcolor = "$blue";
		ngemslot1emr4();
	} elsif ($ngemslot11 == 10) {
		$ngemcolor = "$green";
		ngemslot1emr5();
	} elsif ($ngemslot11 == 11) {
		$ngemcolor = "$red";
		ngemslot1emr4();				
	} else {
		ngemslotwhite();
	}

}

sub ngemcolorr1 {
	$ngemcolor = $ngemr1color;
}

sub ngemcolorr2 {
	$ngemcolor = $ngemr2color;
}

sub ngemcolorr3 {
	$ngemcolor = $ngemr3color;
}

sub ngemcolorr4 {
	$ngemcolor = $ngemr4color;
}

sub ngemcolorr5 {
	$ngemcolor = $ngemr5color;
}


sub ngemreel1 {
	$ngemreel = 1;
	if ($ngemreelspin == 5) {
		$ngemslot1 = 'spining';
		$ngemslot2 = 'spining';
		$ngemslot3 = 'spining';
		$ngemslot4 = 'spining';
		$ngemslot5 = 'spining';
		$ngemslot6 = 'spining';
		$ngemslot7 = 'spining';
		$ngemslot8 = 'spining';
		$ngemslot9 = 'spining';
		$ngemslot10 = 'spining';
		$ngemslot11 = 'spining';
		$ngemslot12 = 'spining';
		$ngemslot13 = 'spining';
		$ngemslot14 = 'spining';
	} else {
		$ngemslot1 = $ngemsvslot1;
		$ngemslot2 = $ngemsvslot1;
		$ngemslot3 = $ngemsvslot1;
		$ngemslot4 = $ngemsvslot1;
		$ngemslot5 = $ngemsvslot1;
		$ngemslot6 = $ngemsvslot1;
		$ngemslot7 = $ngemsvslot1;
		$ngemslot8 = $ngemsvslot1;
		$ngemslot9 = $ngemsvslot1;
		$ngemslot10 = $ngemsvslot1;
		$ngemslot11 = $ngemsvslot1;
		$ngemslot12 = $ngemsvslot1;
		$ngemslot13 = $ngemsvslot1;
		$ngemslot14 = $ngemsvslot1;
	}
	
}

sub ngemreel2 {
	$ngemreel = 2;
	if ($ngemreelspin >= 4) {
		$ngemslot1 = 'spining';
		$ngemslot2 = 'spining';
		$ngemslot3 = 'spining';
		$ngemslot4 = 'spining';
		$ngemslot5 = 'spining';
		$ngemslot6 = 'spining';
		$ngemslot7 = 'spining';
		$ngemslot8 = 'spining';
		$ngemslot9 = 'spining';
		$ngemslot10 = 'spining';
		$ngemslot11 = 'spining';
		$ngemslot12 = 'spining';
		$ngemslot13 = 'spining';
		$ngemslot14 = 'spining';
	} else {
		$ngemslot1 = $ngemsvslot2;
		$ngemslot2 = $ngemsvslot2;
		$ngemslot3 = $ngemsvslot2;
		$ngemslot4 = $ngemsvslot2;
		$ngemslot5 = $ngemsvslot2;
		$ngemslot6 = $ngemsvslot2;
		$ngemslot7 = $ngemsvslot2;
		$ngemslot8 = $ngemsvslot2;
		$ngemslot9 = $ngemsvslot2;
		$ngemslot10 = $ngemsvslot2;
		$ngemslot11 = $ngemsvslot2;
		$ngemslot12 = $ngemsvslot2;
		$ngemslot13 = $ngemsvslot2;
		$ngemslot14 = $ngemsvslot2;
	}
}

sub ngemreel3 {
	$ngemreel = 3;
	if ($ngemreelspin >= 3) {
		$ngemslot1 = 'spining';
		$ngemslot2 = 'spining';
		$ngemslot3 = 'spining';
		$ngemslot4 = 'spining';
		$ngemslot5 = 'spining';
		$ngemslot6 = 'spining';
		$ngemslot7 = 'spining';
		$ngemslot8 = 'spining';
		$ngemslot9 = 'spining';
		$ngemslot10 = 'spining';
		$ngemslot11 = 'spining';
		$ngemslot12 = 'spining';
		$ngemslot13 = 'spining';
		$ngemslot14 = 'spining';
	} else {
		$ngemslot1 = $ngemsvslot3;
		$ngemslot2 = $ngemsvslot3;
		$ngemslot3 = $ngemsvslot3;
		$ngemslot4 = $ngemsvslot3;
		$ngemslot5 = $ngemsvslot3;
		$ngemslot6 = $ngemsvslot3;
		$ngemslot7 = $ngemsvslot3;
		$ngemslot8 = $ngemsvslot3;
		$ngemslot9 = $ngemsvslot3;
		$ngemslot10 = $ngemsvslot3;
		$ngemslot11 = $ngemsvslot3;
		$ngemslot12 = $ngemsvslot3;
		$ngemslot13 = $ngemsvslot3;
		$ngemslot14 = $ngemsvslot3;
	}
}

sub ngemreel4 {
	$ngemreel = 4;
	if (($ngemreelspin >= 2) and ($ngemplaylevel >= 2)) {
		$ngemslot1 = 'spining';
		$ngemslot2 = 'spining';
		$ngemslot3 = 'spining';
		$ngemslot4 = 'spining';
		$ngemslot5 = 'spining';
		$ngemslot6 = 'spining';
		$ngemslot7 = 'spining';
		$ngemslot8 = 'spining';
		$ngemslot9 = 'spining';
		$ngemslot10 = 'spining';
		$ngemslot11 = 'spining';
		$ngemslot12 = 'spining';
		$ngemslot13 = 'spining';
		$ngemslot14 = 'spining';
	} else {
		$ngemslot1 = $ngemsvslot4;
		$ngemslot2 = $ngemsvslot4;
		$ngemslot3 = $ngemsvslot4;
		$ngemslot4 = $ngemsvslot4;
		$ngemslot5 = $ngemsvslot4;
		$ngemslot6 = $ngemsvslot4;
		$ngemslot7 = $ngemsvslot4;
		$ngemslot8 = $ngemsvslot4;
		$ngemslot9 = $ngemsvslot4;
		$ngemslot10 = $ngemsvslot4;
		$ngemslot11 = $ngemsvslot4;
		$ngemslot12 = $ngemsvslot4;
		$ngemslot13 = $ngemsvslot4;
		$ngemslot14 = $ngemsvslot4;
	}
}

sub ngemreel5 {
	$ngemreel = 5;
	if (($ngemreelspin >= 1) and ($ngemplaylevel >= 3)) {
		$ngemslot1 = 'spining';
		$ngemslot2 = 'spining';
		$ngemslot3 = 'spining';
		$ngemslot4 = 'spining';
		$ngemslot5 = 'spining';
		$ngemslot6 = 'spining';
		$ngemslot7 = 'spining';
		$ngemslot8 = 'spining';
		$ngemslot9 = 'spining';
		$ngemslot10 = 'spining';
		$ngemslot11 = 'spining';
		$ngemslot12 = 'spining';
		$ngemslot13 = 'spining';
		$ngemslot14 = 'spining';
	} else {
		$ngemslot1 = $ngemsvslot5;
		$ngemslot2 = $ngemsvslot5;
		$ngemslot3 = $ngemsvslot5;
		$ngemslot4 = $ngemsvslot5;
		$ngemslot5 = $ngemsvslot5;
		$ngemslot6 = $ngemsvslot5;
		$ngemslot7 = $ngemsvslot5;
		$ngemslot8 = $ngemsvslot5;
		$ngemslot9 = $ngemsvslot5;
		$ngemslot10 = $ngemsvslot5;
		$ngemslot11 = $ngemsvslot5;
		$ngemslot12 = $ngemsvslot5;
		$ngemslot13 = $ngemsvslot5;
		$ngemslot14 = $ngemsvslot5;
	}
}

sub ngemmid0 {
	print color 'reset';
	print colored('|',"$boldmagenta on_$bgcmagenta");
	print color 'reset';
}

sub ngemmid1a {
	print color 'reset';
	print colored('<',"$boldblue on_$bgcblue");
	print color 'reset';
}

sub ngemmid1 {
	print color 'reset';
	print colored('>',"$boldblue on_$bgcblue");
	print color 'reset';
}

sub ngemslotb {
	print color 'reset';
	print colored('I',"$boldwhite on_$bgcwhite");
	print colored(' ',"$black on_$bgcblack");
	print colored('I',"$boldwhite on_$bgcwhite");
	print colored('|',"$boldmagenta on_$bgcmagenta");
	print color 'reset';
}

sub ngemslota {
	print color 'reset';
	print colored('III',"$boldwhite on_$bgcwhite");
	print colored('|',"$boldmagenta on_$bgcmagenta");
	print color 'reset';
}

sub ngemangemmoney {
	if ($ngemx123 eq "111") {
		$ngemangemmoney = 2560 * $coin;
		$beepnum = 4;
		$ngemstwin = $ngemstwin + 1;
	} elsif ($ngemx123 eq "222") {
		$ngemangemmoney = 640 * $coin;
		$beepnum = 3;
		$ngemstwin = $ngemstwin + 1;
	} elsif ($ngemx123 eq "333") {
		$ngemangemmoney = 320 * $coin;
		$beepnum = 3;
		$ngemstwin = $ngemstwin + 1;
	} elsif ($ngemx123 eq "444") {
		$ngemangemmoney = 160 * $coin;
		$beepnum = 2;
		$ngemstwin = $ngemstwin + 1;
	} elsif ($ngemx123 eq "555") {
		$ngemangemmoney = 80 * $coin;
		$beepnum = 2;
		$ngemstwin = $ngemstwin + 1;
	} elsif ($ngemx123 eq "666") {
		$ngemangemmoney = 40 * $coin;
		$beepnum = 2;
		$ngemstwin = $ngemstwin + 1;
	} elsif ($ngemx123 eq "777") {
		$ngemangemmoney = 20 * $coin;
		$beepnum = 2;
		$ngemstwin = $ngemstwin + 1;
	} elsif ($ngemx123 eq "545") {
		$ngemangemmoney = 60 * $coin;
		$beepnum = 2;
		$ngemstwin = $ngemstwin + 1;
	} elsif ($ngemx123 eq "656") {
		$ngemangemmoney = 30 * $coin;
		$beepnum = 2;
		$ngemstwin = $ngemstwin + 1;
	} elsif ($ngemx123 eq "767") {
		$ngemangemmoney = 15 * $coin;
		$beepnum = 2;
		$ngemstwin = $ngemstwin + 1;														
	} else {
		$ngemangemmoney = 0;
		$beepnum = 0;
	}
	
	if ($ngemx12 eq "11") {
		$ngemangemmoney = $ngemangemmoney + (24 * $coin);
		$beepnum = $beepnum + 2;
		$ngemstwin = $ngemstwin + 1;
	} elsif ($ngemx12 eq "22") {
		$ngemangemmoney = $ngemangemmoney + (10 * $coin);
		$beepnum = $beepnum + 2;
		$ngemstwin = $ngemstwin + 1;
	} elsif ($ngemx12 eq "33") {
		$ngemangemmoney = $ngemangemmoney + (8 * $coin);
		$beepnum = $beepnum + 2;
		$ngemstwin = $ngemstwin + 1;
	} elsif ($ngemx12 eq "44") {
		$ngemangemmoney = $ngemangemmoney + (6 * $coin);
		$beepnum = $beepnum + 2;
		$ngemstwin = $ngemstwin + 1;
	} else {
		#nothing
	}
	
	if ($ngemx23 eq "11") {
		$ngemangemmoney = $ngemangemmoney + (24 * $coin);
		$beepnum = $beepnum + 2;
		$ngemstwin = $ngemstwin + 1;
	} elsif ($ngemx23 eq "22") {
		$ngemangemmoney = $ngemangemmoney + (10 * $coin);
		$beepnum = $beepnum + 2;
		$ngemstwin = $ngemstwin + 1;
	} elsif ($ngemx23 eq "33") {
		$ngemangemmoney = $ngemangemmoney + (8 * $coin);
		$beepnum = $beepnum + 2;
		$ngemstwin = $ngemstwin + 1;
	} elsif ($ngemx23 eq "44") {
		$ngemangemmoney = $ngemangemmoney + (6 * $coin);
		$beepnum = $beepnum + 2;
		$ngemstwin = $ngemstwin + 1;
	} else {
		#nothing
	}	
	
	if ($ngemsvslot1 eq "1") {
		$ngemangemmoney = $ngemangemmoney + (4 * $coin);
		$ngemstwin = $ngemstwin + 1;
	} elsif ($ngemsvslot1 eq "2") {
		$ngemangemmoney = $ngemangemmoney + (2 * $coin);
		$ngemstwin = $ngemstwin + 1;	
	} else {
		#nothing
	}
	
	if ($ngemsvslot2 eq "1") {
		$ngemangemmoney = $ngemangemmoney + (4 * $coin);
		$ngemstwin = $ngemstwin + 1;
	} elsif ($ngemsvslot2 eq "2") {
		$ngemangemmoney = $ngemangemmoney + (2 * $coin);
		$ngemstwin = $ngemstwin + 1;	
	} else {
		#nothing
	}
	
	if ($ngemsvslot3 eq "1") {
		$ngemangemmoney = $ngemangemmoney + (4 * $coin);
		$ngemstwin = $ngemstwin + 1;
	} elsif ($ngemsvslot3 eq "2") {
		$ngemangemmoney = $ngemangemmoney + (2 * $coin);
		$ngemstwin = $ngemstwin + 1;	
	} else {
		#nothing
	}		
	
	if ($ngemplaylevel >= 2) {		
		if ($ngemsvslot4 eq "1") {
			$ngemangemmoney = $ngemangemmoney + (4 * $coin);
			$ngemstwin = $ngemstwin + 1;
		} elsif ($ngemsvslot4 eq "2") {
			$ngemangemmoney = $ngemangemmoney + (2 * $coin);
			$ngemstwin = $ngemstwin + 1;	
		} else {
			#nothing
		}
		
		if ($ngemx34 eq "11") {
			$ngemangemmoney = $ngemangemmoney + (24 * $coin);
			$beepnum = $beepnum + 2;
			$ngemstwin = $ngemstwin + 1;
		} elsif ($ngemx34 eq "22") {
			$ngemangemmoney = $ngemangemmoney + (10 * $coin);
			$beepnum = $beepnum + 2;
			$ngemstwin = $ngemstwin + 1;
		} elsif ($ngemx34 eq "33") {
			$ngemangemmoney = $ngemangemmoney + (8 * $coin);
			$beepnum = $beepnum + 2;
			$ngemstwin = $ngemstwin + 1;
		} elsif ($ngemx34 eq "44") {
			$ngemangemmoney = $ngemangemmoney + (6 * $coin);
			$beepnum = $beepnum + 2;
			$ngemstwin = $ngemstwin + 1;
		} else {
			#nothing
		}
	
		if ($ngemx234 eq "111") {
			$ngemangemmoney = $ngemangemmoney + (2560 * $coin);
			$beepnum = $beepnum + 4;
			$ngemstwin = $ngemstwin + 1;
		} elsif ($ngemx234 eq "222") {
			$ngemangemmoney = $ngemangemmoney + (640 * $coin);
			$beepnum = $beepnum + 3;
			$ngemstwin = $ngemstwin + 1;
		} elsif ($ngemx234 eq "333") {
			$ngemangemmoney = $ngemangemmoney + (320 * $coin);
			$beepnum = $beepnum + 3;
			$ngemstwin = $ngemstwin + 1;
		} elsif ($ngemx234 eq "444") {
			$ngemangemmoney = $ngemangemmoney + (160 * $coin);
			$beepnum = $beepnum + 2;
			$ngemstwin = $ngemstwin + 1;
		} elsif ($ngemx234 eq "555") {
			$ngemangemmoney = $ngemangemmoney + (80 * $coin);
			$beepnum = $beepnum + 2;
			$ngemstwin = $ngemstwin + 1;
		} elsif ($ngemx234 eq "666") {
			$ngemangemmoney = $ngemangemmoney + (40 * $coin);
			$beepnum = $beepnum + 2;
			$ngemstwin = $ngemstwin + 1;
		} elsif ($ngemx234 eq "777") {
			$ngemangemmoney = $ngemangemmoney + (20 * $coin);
			$beepnum = $beepnum + 2;
			$ngemstwin = $ngemstwin + 1;
		} elsif ($ngemx234 eq "545") {
			$ngemangemmoney = $ngemangemmoney + (60 * $coin);
			$beepnum = 2;
			$ngemstwin = $ngemstwin + 1;
		} elsif ($ngemx234 eq "656") {
			$ngemangemmoney = $ngemangemmoney + (30 * $coin);
			$beepnum = 2;
			$ngemstwin = $ngemstwin + 1;
		} elsif ($ngemx234 eq "767") {
			$ngemangemmoney = $ngemangemmoney + (15 * $coin);
			$beepnum = 2;
			$ngemstwin = $ngemstwin + 1;				
		} else {
			#nothing
		}
		
		#
		
		if ($ngemx1234 eq "1111") {
			$ngemangemmoney = $ngemangemmoney + (7640 * $coin);
			$beepnum = $beepnum + 5;
			$ngemstwin = $ngemstwin + 1;
		} elsif ($ngemx1234 eq "2222") {
			$ngemangemmoney = $ngemangemmoney + (1920 * $coin);
			$beepnum = $beepnum + 4;
			$ngemstwin = $ngemstwin + 1;
		} elsif ($ngemx1234 eq "3333") {
			$ngemangemmoney = $ngemangemmoney + (960 * $coin);
			$beepnum = $beepnum + 4;
			$ngemstwin = $ngemstwin + 1;
		} elsif ($ngemx1234 eq "4444") {
			$ngemangemmoney = $ngemangemmoney + (480 * $coin);
			$beepnum = $beepnum + 3;
			$ngemstwin = $ngemstwin + 1;
		} elsif ($ngemx1234 eq "5555") {
			$ngemangemmoney = $ngemangemmoney + (240 * $coin);
			$beepnum = $beepnum + 3;
			$ngemstwin = $ngemstwin + 1;
		} elsif ($ngemx1234 eq "6666") {
			$ngemangemmoney = $ngemangemmoney + (120 * $coin);
			$beepnum = $beepnum + 3;
			$ngemstwin = $ngemstwin + 1;
		} elsif ($ngemx1234 eq "7777") {
			$ngemangemmoney = $ngemangemmoney + (60 * $coin);
			$beepnum = $beepnum + 3;
			$ngemstwin = $ngemstwin + 1;				
		} else {
			#nothing
		}			
	}
	
	if ($ngemplaylevel >= 3) {
		if ($ngemsvslot5 eq "1") {
			$ngemangemmoney = $ngemangemmoney + (4 * $coin);
			$ngemstwin = $ngemstwin + 1;
		} elsif ($ngemsvslot5 eq "2") {
			$ngemangemmoney = $ngemangemmoney + (2 * $coin);
			$ngemstwin = $ngemstwin + 1;	
		} else {
			#nothing
		}
	
		if ($ngemx45 eq "11") {
			$ngemangemmoney = $ngemangemmoney + (24 * $coin);
			$beepnum = $beepnum + 2;
			$ngemstwin = $ngemstwin + 1;
		} elsif ($ngemx45 eq "22") {
			$ngemangemmoney = $ngemangemmoney + (10 * $coin);
			$beepnum = $beepnum + 2;
			$ngemstwin = $ngemstwin + 1;
		} elsif ($ngemx45 eq "33") {
			$ngemangemmoney = $ngemangemmoney + (8 * $coin);
			$beepnum = $beepnum + 2;
			$ngemstwin = $ngemstwin + 1;
		} elsif ($ngemx45 eq "44") {
			$ngemangemmoney = $ngemangemmoney + (6 * $coin);
			$beepnum = $beepnum + 2;
			$ngemstwin = $ngemstwin + 1;
		} else {
			#nothing
		}
	
		if ($ngemx345 eq "111") {
			$ngemangemmoney = $ngemangemmoney + (2560 * $coin);
			$beepnum = $beepnum + 4;
			$ngemstwin = $ngemstwin + 1;
		} elsif ($ngemx345 eq "222") {
			$ngemangemmoney = $ngemangemmoney + (640 * $coin);
			$beepnum = $beepnum + 3;
			$ngemstwin = $ngemstwin + 1;
		} elsif ($ngemx345 eq "333") {
			$ngemangemmoney = $ngemangemmoney + (320 * $coin);
			$beepnum = $beepnum + 3;
			$ngemstwin = $ngemstwin + 1;
		} elsif ($ngemx345 eq "444") {
			$ngemangemmoney = $ngemangemmoney + (160 * $coin);
			$beepnum = $beepnum + 2;
			$ngemstwin = $ngemstwin + 1;
		} elsif ($ngemx345 eq "555") {
			$ngemangemmoney = $ngemangemmoney + (80 * $coin);
			$beepnum = $beepnum + 2;
			$ngemstwin = $ngemstwin + 1;
		} elsif ($ngemx345 eq "666") {
			$ngemangemmoney = $ngemangemmoney + (40 * $coin);
			$beepnum = $beepnum + 2;
			$ngemstwin = $ngemstwin + 1;
		} elsif ($ngemx345 eq "777") {
			$ngemangemmoney = $ngemangemmoney + (20 * $coin);
			$beepnum = $beepnum + 2;
			$ngemstwin = $ngemstwin + 1;
		} elsif ($ngemx345 eq "545") {
			$ngemangemmoney = $ngemangemmoney + (60 * $coin);
			$beepnum = 2;
			$ngemstwin = $ngemstwin + 1;
		} elsif ($ngemx345 eq "656") {
			$ngemangemmoney = $ngemangemmoney + (30 * $coin);
			$beepnum = 2;
			$ngemstwin = $ngemstwin + 1;
		} elsif ($ngemx345 eq "767") {
			$ngemangemmoney = $ngemangemmoney + (15 * $coin);
			$beepnum = 2;
			$ngemstwin = $ngemstwin + 1;				
		} else {
			#NNNNOOOOOTTTHHIINNGG!!!!
		}
				
		#
		
		if ($ngemx2345 eq "1111") {
			$ngemangemmoney = $ngemangemmoney + (7640 * $coin);
			$beepnum = $beepnum + 5;
			$ngemstwin = $ngemstwin + 1;
		} elsif ($ngemx2345 eq "2222") {
			$ngemangemmoney = $ngemangemmoney + (1920 * $coin);
			$beepnum = $beepnum + 4;
			$ngemstwin = $ngemstwin + 1;
		} elsif ($ngemx2345 eq "3333") {
			$ngemangemmoney = $ngemangemmoney + (960 * $coin);
			$beepnum = $beepnum + 4;
			$ngemstwin = $ngemstwin + 1;
		} elsif ($ngemx2345 eq "4444") {
			$ngemangemmoney = $ngemangemmoney + (480 * $coin);
			$beepnum = $beepnum + 3;
			$ngemstwin = $ngemstwin + 1;
		} elsif ($ngemx2345 eq "5555") {
			$ngemangemmoney = $ngemangemmoney + (240 * $coin);
			$beepnum = $beepnum + 3;
			$ngemstwin = $ngemstwin + 1;
		} elsif ($ngemx2345 eq "6666") {
			$ngemangemmoney = $ngemangemmoney + (120 * $coin);
			$beepnum = $beepnum + 3;
			$ngemstwin = $ngemstwin + 1;
		} elsif ($ngemx2345 eq "7777") {
			$ngemangemmoney = $ngemangemmoney + (60 * $coin);
			$beepnum = $beepnum + 3;
			$ngemstwin = $ngemstwin + 1;				
		} else {
			#nothing
		}
		
		#
		
		if ($ngemx12345 eq "11111") {
			$ngemangemmoney = $ngemangemmoney + (15360 * $coin);
			$beepnum = $beepnum + 5;
			$ngemstwin = $ngemstwin + 1;
		} elsif ($ngemx12345 eq "22222") {
			$ngemangemmoney = $ngemangemmoney + (3840 * $coin);
			$beepnum = $beepnum + 4;
			$ngemstwin = $ngemstwin + 1;
		} elsif ($ngemx12345 eq "33333") {
			$ngemangemmoney = $ngemangemmoney + (1920 * $coin);
			$beepnum = $beepnum + 4;
			$ngemstwin = $ngemstwin + 1;
		} elsif ($ngemx12345 eq "44444") {
			$ngemangemmoney = $ngemangemmoney + (960 * $coin);
			$beepnum = $beepnum + 3;
			$ngemstwin = $ngemstwin + 1;
		} elsif ($ngemx12345 eq "55555") {
			$ngemangemmoney = $ngemangemmoney + (480 * $coin);
			$beepnum = $beepnum + 3;
			$ngemstwin = $ngemstwin + 1;
		} elsif ($ngemx12345 eq "66666") {
			$ngemangemmoney = $ngemangemmoney + (240 * $coin);
			$beepnum = $beepnum + 3;
			$ngemstwin = $ngemstwin + 1;
		} elsif ($ngemx12345 eq "77777") {
			$ngemangemmoney = $ngemangemmoney + (120 * $coin);
			$beepnum = $beepnum + 3;
			$ngemstwin = $ngemstwin + 1;				
		} else {
			#NOTHING!
		}
	}
	
	if ($beepnum == 0) {
		if (($ngemsvslot1 eq "1") or ($ngemsvslot1 eq "2")) {
			$beepnum = 2;
		}
		
		if (($ngemsvslot2 eq "1") or ($ngemsvslot2 eq "2")) {
			$beepnum = 2;
		}
		
		if (($ngemsvslot3 eq "1") or ($ngemsvslot3 eq "2")) {
			$beepnum = 2;
		}
			
		if ($ngemplaylevel >= 2) {
			if (($ngemsvslot4 eq "1") or ($ngemsvslot4 eq "2")) {
				$beepnum = 2;
			}
		}
		
		if ($ngemplaylevel >= 3) {
			if (($ngemsvslot5 eq "1") or ($ngemsvslot5 eq "2")) {
				$beepnum = 2;
			}
		}	
	}
	
	if ($ngemangemmoney == 0) {
		$ngemstlose = $ngemstlose + 1;
	}
}
			
sub ngemmainscreen {
	ngemmid0(); ngemreel1(); ngemcolorr1(); sep; ngemslot1(); sep;  ngemmid0(); ngemreel2(); ngemcolorr2(); sep; ngemslot1(); sep;  ngemmid0(); ngemreel3(); ngemcolorr3(); sep; ngemslot1(); sep;  ngemmid0(); ngemreel4(); ngemcolorr4(); sep; ngemslot1(); sep;  ngemmid0(); ngemreel5(); ngemcolorr5(); sep; ngemslot1(); sep;  ngemmid0(); print colored('   |',"$boldmagenta on_$bgcmagenta"); print"\n";
	ngemmid0(); ngemreel1(); ngemcolorr1(); sep; ngemslot2(); sep;  ngemmid0(); ngemreel2(); ngemcolorr2(); sep; ngemslot2(); sep;  ngemmid0(); ngemreel3(); ngemcolorr3(); sep; ngemslot2(); sep;  ngemmid0(); ngemreel4(); ngemcolorr4(); sep; ngemslot2(); sep;  ngemmid0(); ngemreel5(); ngemcolorr5(); sep; ngemslot2(); sep;  ngemmid0(); print colored('   |',"$boldmagenta on_$bgcmagenta"); print"\n";
	ngemmid0(); ngemreel1(); ngemcolorr1(); sep; ngemslot3(); sep;  ngemmid0(); ngemreel2(); ngemcolorr2(); sep; ngemslot3(); sep;  ngemmid0(); ngemreel3(); ngemcolorr3(); sep; ngemslot3(); sep;  ngemmid0(); ngemreel4(); ngemcolorr4(); sep; ngemslot3(); sep;  ngemmid0(); ngemreel5(); ngemcolorr5(); sep; ngemslot3(); sep;  ngemmid0(); print colored('   |',"$boldmagenta on_$bgcmagenta"); print"\n";
	ngemmid0(); ngemreel1(); ngemcolorr1(); sep; ngemslot4(); sep;  ngemmid0(); ngemreel2(); ngemcolorr2(); sep; ngemslot4(); sep;  ngemmid0(); ngemreel3(); ngemcolorr3(); sep; ngemslot4(); sep;  ngemmid0(); ngemreel4(); ngemcolorr4(); sep; ngemslot4(); sep;  ngemmid0(); ngemreel5(); ngemcolorr5(); sep; ngemslot4(); sep;  ngemmid0(); print colored('   |',"$boldmagenta on_$bgcmagenta"); print"\n";
	ngemmid0(); ngemreel1(); ngemcolorr1(); sep; ngemslot5(); sep;  ngemmid0(); ngemreel2(); ngemcolorr2(); sep; ngemslot5(); sep;  ngemmid0(); ngemreel3(); ngemcolorr3(); sep; ngemslot5(); sep;  ngemmid0(); ngemreel4(); ngemcolorr4(); sep; ngemslot5(); sep;  ngemmid0(); ngemreel5(); ngemcolorr5(); sep; ngemslot5(); sep;  ngemmid0(); ngemslota(); print"\n";
	ngemmid1(); ngemreel1(); ngemcolorr1(); sep; ngemslot6(); sep;  ngemmid1(); ngemreel2(); ngemcolorr2(); sep; ngemslot6(); sep;  ngemmid1(); ngemreel3(); ngemcolorr3(); sep; ngemslot6(); sep;  ngemmid1a(); ngemreel4(); ngemcolorr4(); sep; ngemslot6(); sep;  ngemmid1a(); ngemreel5(); ngemcolorr5(); sep; ngemslot6(); sep;  ngemmid1a(); ngemslotb(); print"\n";
	ngemmid0(); ngemreel1(); ngemcolorr1(); sep; ngemslot7(); sep;  ngemmid0(); ngemreel2(); ngemcolorr2(); sep; ngemslot7(); sep;  ngemmid0(); ngemreel3(); ngemcolorr3(); sep; ngemslot7(); sep;  ngemmid0(); ngemreel4(); ngemcolorr4(); sep; ngemslot7(); sep;  ngemmid0(); ngemreel5(); ngemcolorr5(); sep; ngemslot7(); sep;  ngemmid0(); ngemslotb(); print"\n";
	ngemmid0(); ngemreel1(); ngemcolorr1(); sep; ngemslot8(); sep;  ngemmid0(); ngemreel2(); ngemcolorr2(); sep; ngemslot8(); sep;  ngemmid0(); ngemreel3(); ngemcolorr3(); sep; ngemslot8(); sep;  ngemmid0(); ngemreel4(); ngemcolorr4(); sep; ngemslot8(); sep;  ngemmid0(); ngemreel5(); ngemcolorr5(); sep; ngemslot8(); sep;  ngemmid0(); ngemslotb(); beepalrm();
	ngemmid0(); ngemreel1(); ngemcolorr1(); sep; ngemslot9(); sep;  ngemmid0(); ngemreel2(); ngemcolorr2(); sep; ngemslot9(); sep;  ngemmid0(); ngemreel3(); ngemcolorr3(); sep; ngemslot9(); sep;  ngemmid0(); ngemreel4(); ngemcolorr4(); sep; ngemslot9(); sep;  ngemmid0(); ngemreel5(); ngemcolorr5(); sep; ngemslot9(); sep;  ngemmid0(); ngemslotb(); beepalrm();
	ngemmid0(); ngemreel1(); ngemcolorr1(); sep; ngemslot10(); sep;  ngemmid0(); ngemreel2(); ngemcolorr2(); sep; ngemslot10(); sep;  ngemmid0(); ngemreel3(); ngemcolorr3(); sep; ngemslot10(); sep;  ngemmid0(); ngemreel4(); ngemcolorr4(); sep; ngemslot10(); sep;  ngemmid0(); ngemreel5(); ngemcolorr5(); sep; ngemslot10(); sep;  ngemmid0(); ngemslota(); beepalrm();
	ngemmid0(); ngemreel1(); ngemcolorr1(); sep; ngemslot11(); sep;  ngemmid0(); ngemreel2(); ngemcolorr2(); sep; ngemslot11(); sep;  ngemmid0(); ngemreel3(); ngemcolorr3(); sep; ngemslot11(); sep;  ngemmid0(); ngemreel4(); ngemcolorr4(); sep; ngemslot11(); sep;  ngemmid0(); ngemreel5(); ngemcolorr5(); sep; ngemslot11(); sep;  ngemmid0(); print colored('   |',"$boldmagenta on_$bgcmagenta"); beepalrm();
	print colored('|--------------|--------------|--------------|--------------|--------------|   |',"$boldmagenta on_$bgcmagenta");  beepalrm();
	print colored('|--------------------------------------------------------------------------|   |',"$boldmagenta on_$bgcmagenta");  beepalrm();	
	print colored('|',"$boldmagenta on_$bgcmagenta"); ngemwinnings(); ngemfunds(); print colored('             GPC-SLOTS 2               |',"$boldmagenta on_$bgcmagenta");  beepalrm();
	print colored('\------------------------------------------------------------------------------/',"$boldmagenta on_$bgcmagenta");  beepalrm();	
	
	$beepnum = 0;
}

sub ngemwinnings {
	print colored(' WINNINGS ',"$boldmagenta on_$bgcmagenta");
	sep;
	if ($ngemangemmoney > 9999999999) {
	print colored(sprintf("%.4e", $ngemangemmoney),"$boldcyan on_$bgccyan");
	} elsif ($ngemangemmoney >= 1000000000) {
	print colored("$ngemangemmoney","$boldcyan on_$bgccyan");
	} elsif ($ngemangemmoney >= 100000000) {
	print colored(" $ngemangemmoney","$boldcyan on_$bgccyan");
	} elsif ($ngemangemmoney >= 10000000) {
	print colored("  $ngemangemmoney","$boldcyan on_$bgccyan");
	} elsif ($ngemangemmoney >= 1000000) {
	print colored("   $ngemangemmoney","$boldcyan on_$bgccyan");
	} elsif ($ngemangemmoney >= 100000) {
	print colored("    $ngemangemmoney","$boldcyan on_$bgccyan");
	} elsif ($ngemangemmoney >= 10000) {
	print colored("     $ngemangemmoney","$boldcyan on_$bgccyan");
	} elsif ($ngemangemmoney >= 1000) {
	print colored("      $ngemangemmoney","$boldcyan on_$bgccyan");
	} elsif ($ngemangemmoney >= 100) {
	print colored("       $ngemangemmoney","$boldcyan on_$bgccyan");
	} elsif ($ngemangemmoney >= 10) {
	print colored("        $ngemangemmoney","$boldcyan on_$bgccyan");
	} elsif ($ngemangemmoney >= 1) {
	print colored("         $ngemangemmoney","$boldcyan on_$bgccyan");
	} else {
	print colored("         $ngemangemmoney","$boldcyan on_$bgccyan");
	}
	sep;
}

sub ngemfunds {
	print colored('   FUNDS ',"$boldmagenta on_$bgcmagenta");
	sep;
	if ($money > 9999999999) {
	print colored(sprintf("%.4e", $money),"$boldcyan on_$bgccyan");
	} elsif ($money >= 1000000000) {
	print colored("$money","$boldcyan on_$bgccyan");
	} elsif ($money >= 100000000) {
	print colored(" $money","$boldcyan on_$bgccyan");
	} elsif ($money >= 10000000) {
	print colored("  $money","$boldcyan on_$bgccyan");
	} elsif ($money >= 1000000) {
	print colored("   $money","$boldcyan on_$bgccyan");
	} elsif ($money >= 100000) {
	print colored("    $money","$boldcyan on_$bgccyan");
	} elsif ($money >= 10000) {
	print colored("     $money","$boldcyan on_$bgccyan");
	} elsif ($money >= 1000) {
	print colored("      $money","$boldcyan on_$bgccyan");
	} elsif ($money >= 100) {
	print colored("       $money","$boldcyan on_$bgccyan");
	} elsif ($money >= 10) {
	print colored("        $money","$boldcyan on_$bgccyan");
	} elsif ($money >= 1) {
	print colored("         $money","$boldcyan on_$bgccyan");
	} else {
	print colored("         $money","$boldcyan on_$bgccyan");
	}
	sep;
}

sub ngemtopend {
	print colored('                ',"$white on_$bgcgreen");
	print colored('|',"$boldblack on_$bgcblack");
}

sub ngemtopprint {
	print colored('/---------------------------------------',"$boldmagenta on_$bgcmagenta");
	print colored('---------------------------------------\\',"$boldblack on_$bgcblack");  print"\n";

	print colored('|',"$boldmagenta on_$bgcmagenta");
	print colored('GEM',"$boldgreen on_$bgcmagenta"); 
	print colored(' = 2560',"$white on_$bgcmagenta");
	print colored('  GEMS',"$boldgreen on_$bgcmagenta"); 
	print colored(' = 7640',"$white on_$bgcmagenta");
	print colored('  GEMSS',"$boldgreen on_$bgcmagenta"); 
	print colored(' = 15360 ',"$white on_$bgcmagenta");
	print colored('     *',"$boldwhite on_$bgcblack");
	print colored('       Twilight Mine         ',"$boldcyan on_$bgcblack");
	print colored('*   ',"$boldwhite on_$bgcblack");
	print colored('|',"$boldblack on_$bgcblack"); print"\n";
	
	print colored('|',"$boldmagenta on_$bgcmagenta");
	print colored('GEM',"$boldwhite on_$bgcmagenta"); 
	print colored(' = 640 ',"$white on_$bgcmagenta");
	print colored('*',"$boldmagenta on_$bgcmagenta");
	print colored(' GEMS',"$boldwhite on_$bgcmagenta"); 
	print colored(' = 1920',"$white on_$bgcmagenta");
	print colored('  GEMSS',"$boldwhite on_$bgcmagenta"); 
	print colored(' = 3840  ',"$white on_$bgcmagenta");    #
	print colored(' 2 Tokens - 1 Credit  : P ',"$boldblack on_$bgcblack");
	print colored('*',"$boldwhite on_$bgcblack");
	print colored('  WINNINGS  |',"$boldblack on_$bgcblack");
	print"\n";
	
	print colored('|',"$boldmagenta on_$bgcmagenta");
	print colored('GEM',"$boldred on_$bgcmagenta"); 
	print colored(' = 320',"$white on_$bgcmagenta");
	print colored('   GEMS',"$boldred on_$bgcmagenta"); 
	print colored(' = 960',"$white on_$bgcmagenta");
	print colored('   GEMSS',"$boldred on_$bgcmagenta"); 
	print colored(' = 1920 ',"$white on_$bgcmagenta");    #
	print colored('*',"$boldmagenta on_$bgcmagenta");    
	print colored(' 4 Tokens - 2 Credits : 2P     ARE    ',"$boldblack on_$bgcblack");
	print colored('*',"$boldwhite on_$bgcblack");
	print colored('|',"$boldblack on_$bgcblack");
	print"\n";

	print colored('|',"$boldmagenta on_$bgcmagenta");
	print colored('GEM',"$boldyellow on_$bgcmagenta"); 
	print colored(' = 160',"$white on_$bgcmagenta");
	print colored('   GEMS',"$boldyellow on_$bgcmagenta"); 
	print colored(' = 480',"$white on_$bgcmagenta");
	print colored(' *',"$boldmagenta on_$bgcmagenta");
	print colored(' GEMSS',"$boldyellow on_$bgcmagenta"); 
	print colored(' = 960   ',"$white on_$bgcmagenta");	
	print colored(' 6 Tokens - 3 Credits : 3P  COMPOUNDED |',"$boldblack on_$bgcblack");
	print"\n";

	print colored('|',"$boldmagenta on_$bgcmagenta");
	print colored('GEM',"$boldblue on_$bgcmagenta"); 
	print colored(' = 80',"$white on_$bgcmagenta");
	print colored(' *',"$boldmagenta on_$bgcmagenta");	
	print colored('  GEMS',"$boldblue on_$bgcmagenta"); 
	print colored(' = 240',"$white on_$bgcmagenta");
	print colored('   GEMSS',"$boldblue on_$bgcmagenta"); 
	print colored(' = 480   ',"$white on_$bgcmagenta");	
	print colored('            *                          ',"$boldwhite on_$bgcblack");
	print colored('|',"$boldblack on_$bgcblack");
	print"\n";

	print colored('|',"$boldmagenta on_$bgcmagenta");
	print colored('GEM',"$boldmagenta on_$bgcmagenta"); 
	print colored(' = 40',"$white on_$bgcmagenta");	
	print colored('    GEMS',"$boldmagenta on_$bgcmagenta"); 
	print colored(' = 120',"$white on_$bgcmagenta");
	print colored('  *GEMSS',"$boldmagenta on_$bgcmagenta"); 
	print colored(' = 240   ',"$white on_$bgcmagenta");	
	print colored(' C = Return To Casino Menu      ',"$boldblack on_$bgcblack");
	print colored('*',"$boldwhite on_$bgcblack");
	print colored('      |',"$boldblack on_$bgcblack");
	print"\n";

	print colored('|',"$boldmagenta on_$bgcmagenta");
	print colored('GEM',"$boldcyan on_$bgcmagenta"); 
	print colored(' = 20',"$white on_$bgcmagenta");
	print colored('    GEMS',"$boldcyan on_$bgcmagenta"); 
	print colored(' = 60',"$white on_$bgcmagenta");	
	print colored('    GEMSS',"$boldcyan on_$bgcmagenta"); 
	print colored(' = 120   ',"$white on_$bgcmagenta");	
	print colored(' EXIT = Quit            ',"$boldblack on_$bgcblack");
	print colored('*',"$boldwhite on_$bgcblack");
	print colored('              |',"$boldblack on_$bgcblack");
	print"\n";

	print colored('|',"$boldmagenta on_$bgcmagenta");
	print colored('G',"$boldblue on_$bgcmagenta"); 
	print colored('E',"$boldyellow on_$bgcmagenta");
	print colored('M',"$boldblue on_$bgcmagenta");
	print colored(' = 60',"$white on_$bgcmagenta");
	print colored('      *          ',"$boldmagenta on_$bgcmagenta");
	print colored('GE',"$boldgreen on_$bgcmagenta");
	print colored(' = 24',"$white on_$bgcmagenta");
	print colored('  GE',"$boldred on_$bgcmagenta");
	print colored(' = 8  ',"$white on_$bgcmagenta");
	print colored(' G',"$boldgreen on_$bgcmagenta");
	print colored(' =',"$white on_$bgcmagenta");
	print colored('*',"$boldmagenta on_$bgcmagenta");
	print colored('4',"$white on_$bgcmagenta");
	print colored('                     *        |',"$boldmagenta on_$bgcmagenta");
	print"\n";
	
	print colored('|',"$boldmagenta on_$bgcmagenta");
	print colored('G',"$boldmagenta on_$bgcmagenta"); 
	print colored('E',"$boldblue on_$bgcmagenta");
	print colored('M',"$boldmagenta on_$bgcmagenta");
	print colored(' = 30',"$white on_$bgcmagenta");	
        print colored('    ',"$boldmagenta on_$bgcmagenta");
	print colored('G',"$boldcyan on_$bgcmagenta"); 
	print colored('E',"$boldmagenta on_$bgcmagenta");
	print colored('M',"$boldcyan on_$bgcmagenta");
	print colored(' = 15',"$white on_$bgcmagenta");	
	print colored('     GE',"$boldwhite on_$bgcmagenta");
	print colored(' = 10',"$white on_$bgcmagenta");
	print colored('  GE',"$boldyellow on_$bgcmagenta");
	print colored(' = 6',"$white on_$bgcmagenta");
	print colored(' *',"$boldmagenta on_$bgcmagenta");
	print colored(' G',"$boldwhite on_$bgcmagenta");
	print colored(' = 2',"$white on_$bgcmagenta");
	print colored('         *                *   |',"$boldmagenta on_$bgcmagenta");
	print"\n";

	print colored('|------------------------------------------------------------------------------|',"$boldmagenta on_$bgcmagenta");  print"\n";


	print colored('|',"$boldmagenta on_$bgcmagenta");
	if ($ngemplaylevel >= 1) {
		print colored('   1 CREDIT   ',"$boldwhite on_$bgcmagenta");
	} else {
		print colored('   1 CREDIT   ',"$boldmagenta on_$bgcmagenta");
	}
	print colored(' ',"$boldmagenta on_$bgcmagenta");  

	if ($ngemplaylevel >= 1) {
		print colored('   1 CREDIT   ',"$boldwhite on_$bgcmagenta");
	} else {
		print colored('   1 CREDIT   ',"$boldmagenta on_$bgcmagenta");
	}
	print colored(' ',"$boldmagenta on_$bgcmagenta");  

	if ($ngemplaylevel >= 1) {
		print colored('   1 CREDIT   ',"$boldwhite on_$bgcmagenta");
	} else {
		print colored('   1 CREDIT   ',"$boldmagenta on_$bgcmagenta");
	}
	print colored(' ',"$boldmagenta on_$bgcmagenta");  

	if ($ngemplaylevel >= 2) {
		print colored('   2 CREDITS  ',"$boldwhite on_$bgcmagenta");
	} else {
		print colored('   2 CREDITS  ',"$boldmagenta on_$bgcmagenta");
	}
	print colored(' ',"$boldmagenta on_$bgcmagenta");  

	if ($ngemplaylevel >= 3) {
		print colored('   3 CREDITS  ',"$boldwhite on_$bgcmagenta");
	} else {
		print colored('   3 CREDITS  ',"$boldmagenta on_$bgcmagenta");
	}

	print colored('    |',"$boldmagenta on_$bgcmagenta"); print"\n"; 

	print colored('|--------------------------------------------------------------------------|   |',"$boldmagenta on_$bgcmagenta");  print"\n";
	print colored('|--------------|--------------|--------------|--------------|--------------|   |',"$boldmagenta on_$bgcmagenta");  print"\n";

}



################################################################################################################################
## GENRE: Slot Mahine
## NAME: PotLuck
## AUTHOR: MikeeUSA

sub potluckmain {
	potluckresetvars();
	potluckspinreel();
	potluckreeltrans();
	
	if ($animate == 1) {
		$potluckreelspin = 9;
		potluckmainscreen();
		smallpause();
		newlines();
		
		$potluckreelspin = 8;
		potluckmainscreen();
		smallpause();
		newlines();
	
		$potluckreelspin = 7;
		potluckmainscreen();
		smallpause();
		newlines();
	
		if ($potluckplaylevel >= 2) {
		$potluckreelspin = 6;
		potluckmainscreen();
		smallpause();
		newlines();
		
		$potluckreelspin = 5;
		potluckmainscreen();
		smallpause();
		newlines();
		
		$potluckreelspin = 4;
		potluckmainscreen();
		smallpause();
		newlines();		
		}
		
		if ($potluckplaylevel >= 3) {
		$potluckreelspin = 3;
		potluckmainscreen();
		smallpause();
		newlines();
		
		$potluckreelspin = 2;
		potluckmainscreen();
		smallpause();
		newlines();
		
		$potluckreelspin = 1;
		potluckmainscreen();
		smallpause();
		newlines();		
		}			
	}
	
	$potluckreelspin = 0;
	$potluckxP1p = $potlucksvslot1.$potlucksvslot2.$potlucksvslot3;
	$potluckxP1Zp = $potlucksvslot1.$potlucksvslot2;
	
	$potluckxP2p = $potlucksvslot4.$potlucksvslot5.$potlucksvslot6;
	$potluckxP2Zp = $potlucksvslot4.$potlucksvslot5;
	
	$potluckxP2p4x1 = $potlucksvslot1.$potlucksvslot2.$potlucksvslot4.$potlucksvslot5;
	$potluckxP2p4x2 = $potlucksvslot2.$potlucksvslot3.$potlucksvslot5.$potlucksvslot6;
	
	$potluckxP3p = $potlucksvslot7.$potlucksvslot8.$potlucksvslot9;
	$potluckxP3Zp = $potlucksvslot7.$potlucksvslot8;
	
	$potluckxP3p4x1 = $potlucksvslot1.$potlucksvslot2.$potlucksvslot7.$potlucksvslot8;
	$potluckxP3p4x2 = $potlucksvslot2.$potlucksvslot3.$potlucksvslot8.$potlucksvslot9;
	
	$potluckxP4p = $potlucksvslot7.$potlucksvslot2.$potlucksvslot6;
	$potluckxP4Zp = $potlucksvslot7.$potlucksvslot2;
	
	$potluckxP5p = $potlucksvslot4.$potlucksvslot2.$potlucksvslot9;
	$potluckxP5Zp = $potlucksvslot4.$potlucksvslot2;
	
	$potluckxP6p = $potlucksvslot7.$potlucksvslot1.$potlucksvslot4;
	$potluckxP6Zp = $potlucksvslot7.$potlucksvslot1;
	
	$potluckxP7p = $potlucksvslot8.$potlucksvslot2.$potlucksvslot5;
	$potluckxP7Zp = $potlucksvslot8.$potlucksvslot2;
	
	$potluckxP8p = $potlucksvslot9.$potlucksvslot3.$potlucksvslot6;
	$potluckxP8Zp = $potlucksvslot9.$potlucksvslot3;
	potluckapotluckmoney();
	potluckfundcalc();
	potluckmainscreen();
	ptracker();
	potluckstartinfo();	
}

sub potluckmain2 {
	$potluckplaylevel = 0;
	potluckresetvars();
	potluckreeltrans();
	$potluckxP1p = ' '; #keep, a reset to null type job... well not quite null.
	$potluckxP1Zp = ' ';
	if ($potluckplaylevel >= 2) {
		$potluckxP2p = ' ';
		$potluckxP2Zp = ' ';
	}
	if ($potluckplaylevel >= 3) {
		$potluckxP3p = ' ';
		$potluckxP3Zp = ' ';
	}
	if ($potluckplaylevel >= 4) {
		$potluckxP4p = ' ';
		$potluckxP4Zp = ' ';
	}	
	if ($potluckplaylevel >= 5) {
		$potluckxP5p = ' ';
		$potluckxP5Zp = ' ';
	}
	if ($potluckplaylevel >= 6) {
		$potluckxP6p = ' ';
		$potluckxP6Zp = ' ';
	}	
	if ($potluckplaylevel >= 7) {
		$potluckxP7p = ' ';
		$potluckxP7Zp = ' ';
	}
	if ($potluckplaylevel >= 8) {
		$potluckxP8p = ' ';
		$potluckxP8Zp = ' ';
		$potluckxP2p4x1 = ' ';
		$potluckxP2p4x2 = ' ';
		$potluckxP3p4x1 = ' ';
		$potluckxP3p4x2 = ' ';
	}
	potluckmainscreen();
	potluckstartinfo();	
}

sub potluckresetvars {
	$potluckreelspin = 0;
}

sub potluckstartinfo {
	tokeneval();
	$potluckstartinfo = <STDIN>;
	chomp($potluckstartinfo);
	
	if (($potluckstartinfo eq 'a') or ($potluckstartinfo eq 'A')) {
		$potluckstartinfo = $potluckagaincmd;
	} elsif (($potluckstartinfo eq 'p') or ($potluckstartinfo eq 'P') or ($potluckstartinfo eq '1p') or ($potluckstartinfo eq '1P')
		or ($potluckstartinfo eq '2p') or ($potluckstartinfo eq '2P') or ($potluckstartinfo eq '3p') or ($potluckstartinfo eq '3P')
		or ($potluckstartinfo eq '4p') or ($potluckstartinfo eq '4P') or ($potluckstartinfo eq '5p') or ($potluckstartinfo eq '5P')
		or ($potluckstartinfo eq '6p') or ($potluckstartinfo eq '6P') or ($potluckstartinfo eq '7p') or ($potluckstartinfo eq '7P')
		or ($potluckstartinfo eq '8p') or ($potluckstartinfo eq '8P')) {
		$potluckagaincmd = $potluckstartinfo;
	} else {
		#Do Nothing		
	}

	if (($potluckstartinfo eq 'p') or ($potluckstartinfo eq 'P') or ($potluckstartinfo eq '1p') or ($potluckstartinfo eq '1P')) {
		if ($money >= $coin) {
			$potluckplaylevel = 1;
			$money = $money - $coin;
			$moneyexp = $moneyexp + $coin;
			$potluckstmc2 = $potluckstmc2 + $coin;
			$spins = $spins + 1;
			$potluckstspins = $potluckstspins + 1;
			if ($proadd == 1) {
				$projkpot = $projkpot + $coin;
				$proadd = 0;
			} else {
				$proadd = 1;
			}
			newlines();
			potluckmain();
		} else {
			newlines();
			potluckmain2();		
		}
	} elsif (($potluckstartinfo eq '2p') or ($potluckstartinfo eq '2P')) {
		if ($money >= (2 * $coin)) {
			$potluckplaylevel = 2;
			$money = $money - (2 * $coin);
			$moneyexp = $moneyexp + (2 * $coin);
			$potluckstmc2 = $potluckstmc2 + (2 * $coin);
			$spins = $spins + 1;
			$potluckstspins = $potluckstspins + 1;
			if ($proadd == 1) {
				$projkpot = $projkpot + (2 * $coin);
				$proadd = 0;
			} else {
				$proadd = 1;
			}
			newlines();
			potluckmain();
		} else {
			newlines();
			potluckmain2();		
		}
	} elsif (($potluckstartinfo eq '3p') or ($potluckstartinfo eq '3P')) {
		if ($money >= (3 * $coin)) {
			$potluckplaylevel = 3;
			$money = $money - (3 * $coin);
			$moneyexp = $moneyexp + (3 * $coin);
			$potluckstmc2 = $potluckstmc2 + (3 * $coin);
			$spins = $spins + 1;
			$potluckstspins = $potluckstspins + 1;
			if ($proadd == 1) {
				$projkpot = $projkpot + (3 * $coin);
				$proadd = 0;
			} else {
				$proadd = 1;
			}
			newlines();
			potluckmain();
		} else {
			newlines();
			potluckmain2();		
		}
	} elsif (($potluckstartinfo eq '4p') or ($potluckstartinfo eq '4P')) {
		if ($money >= (4 * $coin)) {
			$potluckplaylevel = 4;
			$money = $money - (4 * $coin);
			$moneyexp = $moneyexp + (4 * $coin);
			$potluckstmc2 = $potluckstmc2 + (4 * $coin);
			$spins = $spins + 1;
			$potluckstspins = $potluckstspins + 1;
			if ($proadd == 1) {
				$projkpot = $projkpot + (4 * $coin);
				$proadd = 0;
			} else {
				$proadd = 1;
			}
			newlines();
			potluckmain();
		} else {
			newlines();
			potluckmain2();		
		}
	} elsif (($potluckstartinfo eq '5p') or ($potluckstartinfo eq '5P')) {
		if ($money >= (5 * $coin)) {
			$potluckplaylevel = 5;
			$money = $money - (5 * $coin);
			$moneyexp = $moneyexp + (5 * $coin);
			$potluckstmc2 = $potluckstmc2 + (5 * $coin);
			$spins = $spins + 1;
			$potluckstspins = $potluckstspins + 1;
			if ($proadd == 1) {
				$projkpot = $projkpot + (5 * $coin);
				$proadd = 0;
			} else {
				$proadd = 1;
			}
			newlines();
			potluckmain();
		} else {
			newlines();
			potluckmain2();		
		}
	} elsif (($potluckstartinfo eq '6p') or ($potluckstartinfo eq '6P')) {
		if ($money >= (6 * $coin)) {
			$potluckplaylevel = 6;
			$money = $money - (6 * $coin);
			$moneyexp = $moneyexp + (6 * $coin);
			$potluckstmc2 = $potluckstmc2 + (6 * $coin);
			$spins = $spins + 1;
			$potluckstspins = $potluckstspins + 1;
			if ($proadd == 1) {
				$projkpot = $projkpot + (6 * $coin);
				$proadd = 0;
			} else {
				$proadd = 1;
			}
			newlines();
			potluckmain();
		} else {
			newlines();
			potluckmain2();		
		}
	} elsif (($potluckstartinfo eq '7p') or ($potluckstartinfo eq '7P')) {
		if ($money >= (7 * $coin)) {
			$potluckplaylevel = 7;
			$money = $money - (7 * $coin);
			$moneyexp = $moneyexp + (7 * $coin);
			$potluckstmc2 = $potluckstmc2 + (7 * $coin);
			$spins = $spins + 1;
			$potluckstspins = $potluckstspins + 1;
			if ($proadd == 1) {
				$projkpot = $projkpot + (7 * $coin);
				$proadd = 0;
			} else {
				$proadd = 1;
			}
			newlines();
			potluckmain();
		} else {
			newlines();
			potluckmain2();
		}
	} elsif (($potluckstartinfo eq '8p') or ($potluckstartinfo eq '8P')) {
		if ($money >= (8 * $coin)) {
			$potluckplaylevel = 8;
			$money = $money - (8 * $coin);
			$moneyexp = $moneyexp + (8 * $coin);
			$potluckstmc2 = $potluckstmc2 + (8 * $coin);
			$spins = $spins + 1;
			$potluckstspins = $potluckstspins + 1;
			if ($proadd == 1) {
				$projkpot = $projkpot + (8 * $coin);
				$proadd = 0;
			} else {
				$proadd = 1;
			}
			newlines();
			potluckmain();
		} else {
			newlines();
			potluckmain2();
		}			
	} elsif (($potluckstartinfo eq 'exit') or ($potluckstartinfo eq 'EXIT') or ($potluckstartinfo eq 'quit') or ($potluckstartinfo eq 'QUIT')) {
		exitgame();
	} elsif (($potluckstartinfo eq 'c') or ($potluckstartinfo eq 'C')) {
		return;
	} else {
		newlines();
		potluckmain2();
	}

}

sub potluckfundcalc {
	$money = $money + $potluckapotluckmoney;
	$potluckstmc = $potluckstmc + $potluckapotluckmoney;
}

sub potluckslot1dheart1  { print colored('    //\\\\//\\\\    ',"$magenta on_$bgcwhite"); }
sub potluckslot1dheart2  { print colored('   //*',"$magenta on_$bgcwhite"); print colored('/\/\\',"$boldmagenta on_$bgcwhite"); print colored('*\\\\   ',"$magenta on_$bgcwhite"); }
sub potluckslot1dheart3  { print colored('   \\\\*',"$magenta on_$bgcwhite"); print colored('\**/',"$boldmagenta on_$bgcwhite"); print colored('*//   ',"$magenta on_$bgcwhite"); }
sub potluckslot1dheart4  { print colored('    \\\\*',"$magenta on_$bgcwhite"); print colored('\/',"$boldmagenta on_$bgcwhite"); print colored('*//    ',"$magenta on_$bgcwhite"); }
sub potluckslot1dheart5  { print colored('     \\\\**//     ',"$magenta on_$bgcwhite"); }
sub potluckslot1dheart6  { print colored('      \\\\//      ',"$magenta on_$bgcwhite"); }

sub potluckslot1dheart1b4{ print colored('4444',"$boldwhite on_$bgcwhite"); print colored('//\\\\//\\\\',"$magenta on_$bgcwhite"); print colored('4444',"$boldwhite on_$bgcwhite"); }
sub potluckslot1dheart2b4{ print colored('  4',"$boldwhite on_$bgcwhite"); print colored('//*',"$magenta on_$bgcwhite"); print colored('/\/\\',"$boldmagenta on_$bgcwhite"); print colored('*\\\\ ',"$magenta on_$bgcwhite"); print colored('4 ',"$boldwhite on_$bgcwhite"); }
sub potluckslot1dheart3b4{ print colored('  4',"$boldwhite on_$bgcwhite"); print colored('\\\\*',"$magenta on_$bgcwhite"); print colored('\**/',"$boldmagenta on_$bgcwhite"); print colored('*//',"$magenta on_$bgcwhite"); print colored('4  ',"$boldwhite on_$bgcwhite"); }
sub potluckslot1dheart4b4{ print colored('  4',"$boldwhite on_$bgcwhite"); print colored(' \\\\*',"$magenta on_$bgcwhite"); print colored('\/',"$boldmagenta on_$bgcwhite"); print colored('*//',"$magenta on_$bgcwhite"); print colored('4   ',"$boldwhite on_$bgcwhite"); }
sub potluckslot1dheart5b4{ print colored('  4',"$boldwhite on_$bgcwhite"); print colored('  \\\\**//',"$magenta on_$bgcwhite"); print colored('4    ',"$boldwhite on_$bgcwhite"); }
sub potluckslot1dheart6b4{ print colored('444444',"$boldwhite on_$bgcwhite"); print colored('\\\\//',"$magenta on_$bgcwhite"); print colored('444444',"$boldwhite on_$bgcwhite"); }

sub potluckslot1swrd1  { print colored('     /#\/#\     ',"$boldred on_$bgcwhite"); }
sub potluckslot1swrd2  { print colored(' ___',"$boldblack on_$bgcwhite"); print colored('/#*##*#\\',"$boldred on_$bgcwhite"); print colored('||  ',"$boldyellow on_$bgcwhite"); }
sub potluckslot1swrd3  { print colored('/_/_/_/_/_/_',"$boldblack on_$bgcwhite"); print colored('||==',"$boldyellow on_$bgcwhite"); }
sub potluckslot1swrd4  { print colored('\_\_\_\_\_\_',"$boldblack on_$bgcwhite"); print colored('||==',"$boldyellow on_$bgcwhite"); }
sub potluckslot1swrd5  { print colored('    ..',"$red on_$bgcwhite"); print colored('\##/  ',"$boldred on_$bgcwhite"); print colored('||  ',"$boldyellow on_$bgcwhite"); }
sub potluckslot1swrd6  { print colored('  ...',"$red on_$bgcwhite"); print colored('  \/       ',"$boldred on_$bgcwhite"); }

sub potluckslot1spad1  { print colored('       /*\      ',"$black on_$bgcwhite"); }
sub potluckslot1spad2  { print colored('      /%S*\     ',"$black on_$bgcwhite"); }
sub potluckslot1spad3  { print colored('     /%S~S*\    ',"$black on_$bgcwhite"); }
sub potluckslot1spad4  { print colored('    /%S~S~S*\   ',"$black on_$bgcwhite"); }
sub potluckslot1spad5  { print colored('    \__/|\__/   ',"$black on_$bgcwhite"); }
sub potluckslot1spad6  { print colored('       /_\      ',"$black on_$bgcwhite"); }

sub potluckslot1spad1b2{ print colored('      22222     ',"$boldwhite on_$bgcwhite"); }
sub potluckslot1spad2b2{ print colored('     2',"$boldwhite on_$bgcwhite"); print colored('/%S*\\',"$black on_$bgcwhite"); print colored('2    ',"$boldwhite on_$bgcwhite"); }
sub potluckslot1spad3b2{ print colored('     /%S~',"$black on_$bgcwhite"); print colored('22',"$boldwhite on_$bgcwhite"); print colored('\    ',"$black on_$bgcwhite"); }
sub potluckslot1spad4b2{ print colored('    /%S',"$black on_$bgcwhite"); print colored('22',"$boldwhite on_$bgcwhite"); print colored('~S*\   ',"$black on_$bgcwhite"); }
sub potluckslot1spad5b2{ print colored('    \\',"$black on_$bgcwhite"); print colored('22',"$boldwhite on_$bgcwhite"); print colored('/|\__/   ',"$black on_$bgcwhite"); }
sub potluckslot1spad6b2{ print colored('     22',"$boldwhite on_$bgcwhite"); print colored('/_\\',"$black on_$bgcwhite"); print colored('22    ',"$boldwhite on_$bgcwhite"); }

sub potluckslot1clov1  { print colored('       /O\      ',"$green on_$bgcwhite"); }
sub potluckslot1clov2  { print colored('    __/OOO\__   ',"$green on_$bgcwhite"); }
sub potluckslot1clov3  { print colored('   /OO0OOO0Oo\  ',"$green on_$bgcwhite"); }
sub potluckslot1clov4  { print colored('   |OOOOOOOOO|  ',"$green on_$bgcwhite"); }
sub potluckslot1clov5  { print colored('   \__/ 00\__/  ',"$green on_$bgcwhite"); }
sub potluckslot1clov6  { print colored('       00       ',"$green on_$bgcwhite"); }

sub potluckslot1heart1  { print colored('     /#\/#\     ',"$red on_$bgcwhite"); }
sub potluckslot1heart2  { print colored('    /#*##*#\    ',"$red on_$bgcwhite"); }
sub potluckslot1heart3  { print colored('    \#****#/    ',"$red on_$bgcwhite"); }
sub potluckslot1heart4  { print colored('     \#**#/     ',"$red on_$bgcwhite"); }
sub potluckslot1heart5  { print colored('      \##/      ',"$red on_$bgcwhite"); }
sub potluckslot1heart6  { print colored('       \/       ',"$red on_$bgcwhite"); }

sub potluckslot1coin1  { print colored('       SSSSS    ',"$boldwhite on_$bgcwhite"); }
sub potluckslot1coin2  { print colored('   GGGGG',"$boldyellow on_$bgcwhite"); print colored('ssssSS  ',"$boldwhite on_$bgcwhite"); }
sub potluckslot1coin3  { print colored(' GGgggggGG',"$boldyellow on_$bgcwhite"); print colored('sssS  ',"$boldwhite on_$bgcwhite"); }
sub potluckslot1coin4  { print colored(' GgggggggG',"$boldyellow on_$bgcwhite"); print colored('ssSS  ',"$boldwhite on_$bgcwhite"); }
sub potluckslot1coin5  { print colored(' GGgggggGG',"$boldyellow on_$bgcwhite"); print colored('SS',"$boldwhite on_$bgcwhite"); print colored('ss  ',"$boldblack on_$bgcwhite"); }
sub potluckslot1coin6  { print colored('   GGGGG',"$boldyellow on_$bgcwhite"); print colored('gg',"$yellow on_$bgcwhite"); print colored('ss    ',"$boldblack on_$bgcwhite"); }

sub potluckslot1coin1bh{ print colored('       IIIII    ',"$boldblack on_$bgcwhite"); }
sub potluckslot1coin2bh{ print colored('   CCCCC',"$yellow on_$bgcwhite"); print colored('iiiiII  ',"$boldblack on_$bgcwhite"); }
sub potluckslot1coin3bh{ print colored(' CCc',"$yellow on_$bgcwhite"); print colored('1',"$boldblack on_$bgcwhite"); print colored('cccCC',"$yellow on_$bgcwhite"); print colored('iiiI  ',"$boldblack on_$bgcwhite"); }
sub potluckslot1coin4bh{ print colored(' Cccc',"$yellow on_$bgcwhite"); print colored('/',"$boldblack on_$bgcwhite"); print colored('cccC',"$yellow on_$bgcwhite"); print colored('iiII  ',"$boldblack on_$bgcwhite"); }
sub potluckslot1coin5bh{ print colored(' CCccc',"$yellow on_$bgcwhite"); print colored('2',"$boldblack on_$bgcwhite"); print colored('cCC',"$yellow on_$bgcwhite"); print colored('II',"$boldblack on_$bgcwhite"); print colored('ii  ',"$black on_$bgcwhite"); }
sub potluckslot1coin6bh{ print colored('   CCCCC',"$yellow on_$bgcwhite"); print colored('cc',"$boldyellow on_$bgcwhite"); print colored('ii    ',"$black on_$bgcwhite"); }

sub potluckslot1coin1bs{ print colored('       SSSSS    ',"$boldwhite on_$bgcwhite"); }
sub potluckslot1coin2bs{ print colored('   IIIII',"$boldblack on_$bgcwhite"); print colored('ssssSS  ',"$boldwhite on_$bgcwhite"); }
sub potluckslot1coin3bs{ print colored(' IIi',"$boldblack on_$bgcwhite"); print colored('3',"$black on_$bgcwhite"); print colored('iiiII',"$boldblack on_$bgcwhite"); print colored('sssS  ',"$boldwhite on_$bgcwhite"); }
sub potluckslot1coin4bs{ print colored(' Iiii',"$boldblack on_$bgcwhite"); print colored('/',"$black on_$bgcwhite"); print colored('iiiI',"$boldblack on_$bgcwhite"); print colored('ssSS  ',"$boldwhite on_$bgcwhite"); }
sub potluckslot1coin5bs{ print colored(' IIiii',"$boldblack on_$bgcwhite"); print colored('4',"$black on_$bgcwhite"); print colored('iII',"$boldblack on_$bgcwhite"); print colored('SS',"$boldwhite on_$bgcwhite"); print colored('ss  ',"$boldblack on_$bgcwhite"); }
sub potluckslot1coin6bs{ print colored('   IIIII',"$boldblack on_$bgcwhite"); print colored('ii',"$black on_$bgcwhite"); print colored('ss    ',"$boldblack on_$bgcwhite"); }


sub potluckslot1hsho1  { print colored('  \###/  \###/  ',"$yellow on_$bgcwhite"); }
sub potluckslot1hsho2  { print colored('   |',"$yellow on_$bgcwhite");print colored('0',"$boldyellow on_$bgcwhite");print colored('|    |',"$yellow on_$bgcwhite");print colored('0',"$boldyellow on_$bgcwhite");print colored('|   ',"$yellow on_$bgcwhite"); }
sub potluckslot1hsho3  { print colored('   |#|    |#|   ',"$yellow on_$bgcwhite"); }
sub potluckslot1hsho4  { print colored('   |#',"$yellow on_$bgcwhite");print colored('0',"$boldyellow on_$bgcwhite");print colored('\__/',"$yellow on_$bgcwhite");print colored('0',"$boldyellow on_$bgcwhite");print colored('#|   ',"$yellow on_$bgcwhite"); }
sub potluckslot1hsho5  { print colored('    \######/    ',"$yellow on_$bgcwhite"); }
sub potluckslot1hsho6  { print colored('      \##/      ',"$yellow on_$bgcwhite"); }

sub potluckslot12xmulti3  { 
print colored(' ',"$white on_$bgcwhite");
print colored('!2X!2X!!X2!X2!',"$boldwhite on_$bgcblack");
print colored(' ',"$white on_$bgcwhite");
}

sub potluckslot12xmulti4  { 
print colored(' ',"$white on_$bgcwhite");
print colored('!!MULTIPLIER!!',"$boldwhite on_$bgcblack");
print colored(' ',"$white on_$bgcwhite");
}

sub potluckslot13xmulti3  { 
print colored(' ',"$white on_$bgcwhite");
print colored('!3X!3X!!X3!X3!',"$boldyellow on_$bgcgreen");
print colored(' ',"$white on_$bgcwhite");
}

sub potluckslot13xmulti4  { 
print colored(' ',"$white on_$bgcwhite");
print colored('!!MULTIPLIER!!',"$boldyellow on_$bgcgreen");
print colored(' ',"$white on_$bgcwhite");
}

sub potluckslotwhite { print colored('                ',"$white on_$bgcwhite"); }

sub potluckslotspining { print colored('||||||||||||||||',"$boldwhite on_$bgcwhite"); }


sub potluck45init {
	$potluckslotsymbol4 = int(rand($potluckrandnums));
	$potluckslotsymbol5 = int(rand($potluckrandnums));
	$potluckslotsymbol6 = int(rand($potluckrandnums));
	$potluckslotsymbol7 = int(rand($potluckrandnums));
	$potluckslotsymbol8 = int(rand($potluckrandnums));
	$potluckslotsymbol9 = int(rand($potluckrandnums));
	
	$potluckslotdh4 = int(rand(2));
	$potluckslotdh5 = int(rand(2));
	$potluckslotdh6 = int(rand(2));
	$potluckslotdh7 = int(rand(2));
	$potluckslotdh8 = int(rand(2));
	$potluckslotdh9 = int(rand(2));
	
	$potluckslotbns4 = int(rand(10));
	$potluckslotbns5 = int(rand(10));
	$potluckslotbns6 = int(rand(10));
	$potluckslotbns7 = int(rand(10));
	$potluckslotbns8 = int(rand(10));
	$potluckslotbns9 = int(rand(10));
}

sub potluckspinreel {
	$potluckslotsymbol1 = int(rand($potluckrandnums));
	$potluckslotsymbol2 = int(rand($potluckrandnums));
	$potluckslotsymbol3 = int(rand($potluckrandnums));
	
	$potluckslotdh1 = int(rand(2));
	$potluckslotdh2 = int(rand(2));
	$potluckslotdh3 = int(rand(2));
	
	$potluckslotbns1 = int(rand(10));
	$potluckslotbns2 = int(rand(10));
	$potluckslotbns3 = int(rand(10));
	
	
	if ($potluckplaylevel >= 2) { 
		$potluckslotsymbol4 = int(rand($potluckrandnums));
		$potluckslotsymbol5 = int(rand($potluckrandnums));
		$potluckslotsymbol6 = int(rand($potluckrandnums));
		
		$potluckslotdh4 = int(rand(2));
		$potluckslotdh5 = int(rand(2));
		$potluckslotdh6 = int(rand(2));
		
		$potluckslotbns4 = int(rand(10));
		$potluckslotbns5 = int(rand(10));
		$potluckslotbns6 = int(rand(10));
	}
	
	if ($potluckplaylevel >= 3) { 
		$potluckslotsymbol7 = int(rand($potluckrandnums));
		$potluckslotsymbol8 = int(rand($potluckrandnums));
		$potluckslotsymbol9 = int(rand($potluckrandnums));
		
		$potluckslotdh7 = int(rand(2));
		$potluckslotdh8 = int(rand(2));
		$potluckslotdh9 = int(rand(2));
		
		$potluckslotbns7 = int(rand(10));
		$potluckslotbns8 = int(rand(10));
		$potluckslotbns9 = int(rand(10));
	}
	
	if ($potluckplaylevel >= 6) { 
		$potluckslotsymbolX2M = int(rand(10));
	} else {
		$potluckslotsymbolX2M = 0;
	}
	
	if ($potluckplaylevel == 8) {
		if ($potluckslotsymbolX2M != 5) {
			$potluckslotsymbolX3M = int(rand(15));
		} else {
			$potluckslotsymbolX3M = 0;
		}
	} else {
		$potluckslotsymbolX3M = 0;
	}	
}

sub potluckreeltrans {
	$potluckslotmltp = 0; #Reset this, will determine bonus multiple
	$potluckslotdivd = 0; #Reset this, will determine bonus reducing multiple
	
	if ($potluckslotsymbol1 <= 4) {
		$potlucksvslot1 = 7;
	} elsif ($potluckslotsymbol1 <= 8) {
		$potlucksvslot1 = 8;
	} elsif ($potluckslotsymbol1 <= 10) {
		$potlucksvslot1 = 'x';
	} elsif ($potluckslotsymbol1 <= 12) {
		$potlucksvslot1 = 9;	
	} elsif ($potluckslotsymbol1 <= 22) {
		$potlucksvslot1 = 6;
	} elsif ($potluckslotsymbol1 <= 30) {
		$potlucksvslot1 = 5;
		if ($potluckslotbns1 == 4) {
			$potluckslotdivd = $potluckslotdivd + 2;
		} elsif ($potluckslotbns1 == 6) {
			$potluckslotdivd = $potluckslotdivd + 1.33333333333333333333;
		}
	} elsif ($potluckslotsymbol1 <= 36) {
		$potlucksvslot1 = 4;
	} elsif ($potluckslotsymbol1 <= 40) {
		$potlucksvslot1 = 3;
	} elsif ($potluckslotsymbol1 <= 42) {
		$potlucksvslot1 = 2;
		if ($potluckslotbns1 == 7) {
			$potluckslotmltp = $potluckslotmltp + 2;
		}
	} elsif ($potluckslotsymbol1 == 43) {
		$potlucksvslot1 = 1;
	} elsif (($potluckslotsymbol1 == 44) && ($potluckslotdh1 == 1)) {
		$potlucksvslot1 = 'd';
		if ($potluckslotbns1 == 7) {
			$potluckslotmltp = $potluckslotmltp + 4;
		}
	} elsif ($potluckslotsymbol1 >= 44) {
		$potlucksvslot1 = 7;				
	} else {
		$potlucksvslot1 = 0;
	}
	
	if ($potluckslotsymbol2 <= 4) {
		$potlucksvslot2 = 7;
		$potluckslotsymbolX2M = 0;
		$potluckslotsymbolX3M = 0;
	} elsif ($potluckslotsymbol2 <= 8) {
		$potlucksvslot2 = 8;
		$potluckslotsymbolX2M = 0;
		$potluckslotsymbolX3M = 0;
	} elsif ($potluckslotsymbol2 <= 10) {
		$potlucksvslot2 = 'x';
		$potluckslotsymbolX2M = 0;
		$potluckslotsymbolX3M = 0;
	} elsif ($potluckslotsymbol2 <= 12) {
		$potlucksvslot2 = 9;
		$potluckslotsymbolX2M = 0;
		$potluckslotsymbolX3M = 0;	
	} elsif ($potluckslotsymbol2 <= 22) {
		$potlucksvslot2 = 6;
	} elsif ($potluckslotsymbol2 <= 30) {
		$potlucksvslot2 = 5;
		if ($potluckslotbns2 == 4) {
			$potluckslotdivd = $potluckslotdivd + 2;
		} elsif ($potluckslotbns2 == 6) {
			$potluckslotdivd = $potluckslotdivd + 1.33333333333333333333;
		}
	} elsif ($potluckslotsymbol2 <= 36) {
		$potlucksvslot2 = 4;
	} elsif ($potluckslotsymbol2 <= 40) {
		$potlucksvslot2 = 3;
	} elsif ($potluckslotsymbol2 <= 42) {
		$potlucksvslot2 = 2;
		if ($potluckslotbns2 == 7) {
			$potluckslotmltp = $potluckslotmltp + 2;
		}
	} elsif ($potluckslotsymbol2 == 43) {
		$potlucksvslot2 = 1;
	} elsif (($potluckslotsymbol2 == 44) && ($potluckslotdh2 == 1)) {
		$potlucksvslot2 = 'd';
		if ($potluckslotbns2 == 7) {
			$potluckslotmltp = $potluckslotmltp + 4;
		}
	} elsif ($potluckslotsymbol2 >= 44) {
		$potlucksvslot2 = 8;
		$potluckslotsymbolX2M = 0;
		$potluckslotsymbolX3M = 0;		
	} else {
		$potlucksvslot2 = 0;
	}
	
	if ($potluckslotsymbol3 <= 4) {
		$potlucksvslot3 = 7;
	} elsif ($potluckslotsymbol3 <= 8) {
		$potlucksvslot3 = 8;
	} elsif ($potluckslotsymbol3 <= 10) {
		$potlucksvslot3 = 'x';
	} elsif ($potluckslotsymbol3 <= 12) {
		$potlucksvslot3 = 9;	
	} elsif ($potluckslotsymbol3 <= 22) {
		$potlucksvslot3 = 6;
	} elsif ($potluckslotsymbol3 <= 30) {
		$potlucksvslot3 = 5;
		if ($potluckslotbns3 == 4) {
			$potluckslotdivd = $potluckslotdivd + 2;
		} elsif ($potluckslotbns3 == 6) {
			$potluckslotdivd = $potluckslotdivd + 1.33333333333333333333;
		}
	} elsif ($potluckslotsymbol3 <= 36) {
		$potlucksvslot3 = 4;
	} elsif ($potluckslotsymbol3 <= 40) {
		$potlucksvslot3 = 3;
	} elsif ($potluckslotsymbol3 <= 42) {
		$potlucksvslot3 = 2;
		if ($potluckslotbns3 == 7) {
			$potluckslotmltp = $potluckslotmltp + 2;
		}
	} elsif ($potluckslotsymbol3 == 43) {
		$potlucksvslot3 = 1;
	} elsif (($potluckslotsymbol3 == 44) && ($potluckslotdh3 == 1)) {
		$potlucksvslot3 = 'd';
		if ($potluckslotbns3 == 7) {
			$potluckslotmltp = $potluckslotmltp + 4;
		}
	} elsif ($potluckslotsymbol3 >= 44) {
		$potlucksvslot3 = 9;		
	} else {
		$potlucksvslot3 = 0;
	}
	
	if ($potluckslotsymbol4 <= 4) {
		$potlucksvslot4 = 7;
	} elsif ($potluckslotsymbol4 <= 8) {
		$potlucksvslot4 = 8;
	} elsif ($potluckslotsymbol4 <= 10) {
		$potlucksvslot4 = 'x';
	} elsif ($potluckslotsymbol4 <= 12) {
		$potlucksvslot4 = 9;	
	} elsif ($potluckslotsymbol4 <= 22) {
		$potlucksvslot4 = 6;
	} elsif ($potluckslotsymbol4 <= 30) {
		$potlucksvslot4 = 5;
		if (($potluckplaylevel >= 2) && ($potluckslotbns4 == 4)) {
			#Playlevel must be 2 lines or greater to spin these reels
			$potluckslotdivd = $potluckslotdivd + 2;
		} elsif (($potluckplaylevel >= 2) && ($potluckslotbns4 == 6)) {
			$potluckslotdivd = $potluckslotdivd + 1.33333333333333333333;
		}
	} elsif ($potluckslotsymbol4 <= 36) {
		$potlucksvslot4 = 4;
	} elsif ($potluckslotsymbol4 <= 40) {
		$potlucksvslot4 = 3;
	} elsif ($potluckslotsymbol4 <= 42) {
		$potlucksvslot4 = 2;
		if (($potluckplaylevel >= 2) && ($potluckslotbns4 == 7)) {
			#Playlevel must be 2 lines or greater to spin these reels
			$potluckslotmltp = $potluckslotmltp + 2;
		}
	} elsif ($potluckslotsymbol4 == 43) {
		$potlucksvslot4 = 1;
	} elsif (($potluckslotsymbol4 == 44) && ($potluckslotdh4 == 1)) {
		$potlucksvslot4 = 'd';
		if (($potluckplaylevel >= 2) && ($potluckslotbns4 == 7)) {
			#Playlevel must be 2 lines or greater to spin these reels
			$potluckslotmltp = $potluckslotmltp + 4;
		}
	} elsif ($potluckslotsymbol4 >= 44) {
		$potlucksvslot4 = 9;			
	} else {
		$potlucksvslot4 = 0;
	}		
	
	if ($potluckslotsymbol5 <= 4) {
		$potlucksvslot5 = 7;
	} elsif ($potluckslotsymbol5 <= 8) {
		$potlucksvslot5 = 8;
	} elsif ($potluckslotsymbol5 <= 10) {
		$potlucksvslot5 = 'x';
	} elsif ($potluckslotsymbol5 <= 12) {
		$potlucksvslot5 = 9;
	} elsif ($potluckslotsymbol5 <= 22) {
		$potlucksvslot5 = 6;
	} elsif ($potluckslotsymbol5 <= 30) {
		$potlucksvslot5 = 5;
		if (($potluckplaylevel >= 2) && ($potluckslotbns5 == 4)) {
			#Playlevel must be 2 lines or greater to spin these reels
			$potluckslotdivd = $potluckslotdivd + 2;
		} elsif (($potluckplaylevel >= 2) && ($potluckslotbns5 == 6)) {
			$potluckslotdivd = $potluckslotdivd + 1.33333333333333333333;
		}
	} elsif ($potluckslotsymbol5 <= 36) {
		$potlucksvslot5 = 4;
	} elsif ($potluckslotsymbol5 <= 40) {
		$potlucksvslot5 = 3;
	} elsif ($potluckslotsymbol5 <= 42) {
		$potlucksvslot5 = 2;
		if (($potluckplaylevel >= 2) && ($potluckslotbns5 == 7)) {
			#Playlevel must be 2 lines or greater to spin these reels
			$potluckslotmltp = $potluckslotmltp + 2;
		}
	} elsif ($potluckslotsymbol5 == 43) {
		$potlucksvslot5 = 1;
	} elsif (($potluckslotsymbol5 == 44) && ($potluckslotdh5 == 1)) {
		$potlucksvslot5 = 'd';
		if (($potluckplaylevel >= 2) && ($potluckslotbns5 == 7)) {
			#Playlevel must be 2 lines or greater to spin these reels
			$potluckslotmltp = $potluckslotmltp + 4;
		}
	} elsif ($potluckslotsymbol5 >= 44) {
		$potlucksvslot5 = 8;			
	} else {
		$potlucksvslot5 = 0;
	}
	
	if ($potluckslotsymbol6 <= 4) {
		$potlucksvslot6 = 7;
	} elsif ($potluckslotsymbol6 <= 8) {
		$potlucksvslot6 = 8;
	} elsif ($potluckslotsymbol6 <= 10) {
		$potlucksvslot6 = 'x';
	} elsif ($potluckslotsymbol6 <= 12) {
		$potlucksvslot6 = 9;	
	} elsif ($potluckslotsymbol6 <= 22) {
		$potlucksvslot6 = 6;
	} elsif ($potluckslotsymbol6 <= 30) {
		$potlucksvslot6 = 5;
		if (($potluckplaylevel >= 2) && ($potluckslotbns6 == 4)) {
			#Playlevel must be 2 lines or greater to spin these reels
			$potluckslotdivd = $potluckslotdivd + 2;
		} elsif (($potluckplaylevel >= 2) && ($potluckslotbns6 == 6)) {
			$potluckslotdivd = $potluckslotdivd + 1.33333333333333333333;
		}
	} elsif ($potluckslotsymbol6 <= 36) {
		$potlucksvslot6 = 4;
	} elsif ($potluckslotsymbol6 <= 40) {
		$potlucksvslot6 = 3;
	} elsif ($potluckslotsymbol6 <= 42) {
		$potlucksvslot6 = 2;
		if (($potluckplaylevel >= 2) && ($potluckslotbns6 == 7)) {
			#Playlevel must be 2 lines or greater to spin these reels
			$potluckslotmltp = $potluckslotmltp + 2;
		}
	} elsif ($potluckslotsymbol6 == 43) {
		$potlucksvslot6 = 1;
	} elsif (($potluckslotsymbol6 == 44) && ($potluckslotdh6 == 1)) {
		$potlucksvslot6 = 'd';
		if (($potluckplaylevel >= 2) && ($potluckslotbns6 == 7)) {
			#Playlevel must be 2 lines or greater to spin these reels
			$potluckslotmltp = $potluckslotmltp + 4;
		}
	} elsif ($potluckslotsymbol6 >= 44) {
		$potlucksvslot6 = 7;			
	} else {
		$potlucksvslot6 = 0;
	}
	
	if ($potluckslotsymbol7 <= 4) {
		$potlucksvslot7 = 7;
	} elsif ($potluckslotsymbol7 <= 8) {
		$potlucksvslot7 = 8;
	} elsif ($potluckslotsymbol7 <= 10) {
		$potlucksvslot7 = 'x';
	} elsif ($potluckslotsymbol7 <= 12) {
		$potlucksvslot7 = 9;	
	} elsif ($potluckslotsymbol7 <= 22) {
		$potlucksvslot7 = 6;
	} elsif ($potluckslotsymbol7 <= 30) {
		$potlucksvslot7 = 5;
		if (($potluckplaylevel >= 3) && ($potluckslotbns7 == 4)) {
			#Playlevel must be 3 lines or greater to spin these reels
			$potluckslotdivd = $potluckslotdivd + 2;
		} elsif (($potluckplaylevel >= 3) && ($potluckslotbns7 == 6)) {
			$potluckslotdivd = $potluckslotdivd + 1.33333333333333333333;
		}
	} elsif ($potluckslotsymbol7 <= 36) {
		$potlucksvslot7 = 4;
	} elsif ($potluckslotsymbol7 <= 40) {
		$potlucksvslot7 = 3;
	} elsif ($potluckslotsymbol7 <= 42) {
		$potlucksvslot7 = 2;
		if (($potluckplaylevel >= 3) && ($potluckslotbns7 == 7)) {
			#Playlevel must be 3 lines or greater to spin these reels
			$potluckslotmltp = $potluckslotmltp + 2;
		}
	} elsif ($potluckslotsymbol7 == 43) {
		$potlucksvslot7 = 1;
	} elsif (($potluckslotsymbol7 == 44) && ($potluckslotdh7 == 1)) {
		$potlucksvslot7 = 'd';
		if (($potluckplaylevel >= 3) && ($potluckslotbns7 == 7)) {
			#Playlevel must be 3 lines or greater to spin these reels
			$potluckslotmltp = $potluckslotmltp + 4;
		}
	} elsif ($potluckslotsymbol7 >= 44) {
		$potlucksvslot7 = 8;			
	} else {
		$potlucksvslot7 = 0;
	}
	
	if ($potluckslotsymbol8 <= 4) {
		$potlucksvslot8 = 7;
	} elsif ($potluckslotsymbol8 <= 8) {
		$potlucksvslot8 = 8;
	} elsif ($potluckslotsymbol8 <= 10) {
		$potlucksvslot8 = 'x';
	} elsif ($potluckslotsymbol8 <= 12) {
		$potlucksvslot8 = 9;	
	} elsif ($potluckslotsymbol8 <= 22) {
		$potlucksvslot8 = 6;
	} elsif ($potluckslotsymbol8 <= 30) {
		$potlucksvslot8 = 5;
		if (($potluckplaylevel >= 3) && ($potluckslotbns8 == 4)) {
			#Playlevel must be 3 lines or greater to spin these reels
			$potluckslotdivd = $potluckslotdivd + 2;
		} elsif (($potluckplaylevel >= 3) && ($potluckslotbns8 == 6)) {
			$potluckslotdivd = $potluckslotdivd + 1.33333333333333333333;
		}
	} elsif ($potluckslotsymbol8 <= 36) {
		$potlucksvslot8 = 4;
	} elsif ($potluckslotsymbol8 <= 40) {
		$potlucksvslot8 = 3;
	} elsif ($potluckslotsymbol8 <= 42) {
		$potlucksvslot8 = 2;
		if (($potluckplaylevel >= 3) && ($potluckslotbns8 == 7)) {
			#Playlevel must be 3 lines or greater to spin these reels
			$potluckslotmltp = $potluckslotmltp + 2;
		}
	} elsif ($potluckslotsymbol8 == 43) {
		$potlucksvslot8 = 1;
	} elsif (($potluckslotsymbol8 == 44) && ($potluckslotdh8 == 1)) {
		$potlucksvslot8 = 'd';
		if (($potluckplaylevel >= 3) && ($potluckslotbns8 == 7)) {
			#Playlevel must be 3 lines or greater to spin these reels
			$potluckslotmltp = $potluckslotmltp + 4;
		}
	} elsif ($potluckslotsymbol8 >= 44) {
		$potlucksvslot8 = 7;			
	} else {
		$potlucksvslot8 = 0;
	}
	
	if ($potluckslotsymbol9 <= 4) {
		$potlucksvslot9 = 7;
	} elsif ($potluckslotsymbol9 <= 8) {
		$potlucksvslot9 = 8;
	} elsif ($potluckslotsymbol9 <= 10) {
		$potlucksvslot9 = 'x';
	} elsif ($potluckslotsymbol9 <= 12) {
		$potlucksvslot9 = 9;	
	} elsif ($potluckslotsymbol9 <= 22) {
		$potlucksvslot9 = 6;
	} elsif ($potluckslotsymbol9 <= 30) {
		$potlucksvslot9 = 5;
		if (($potluckplaylevel >= 3) && ($potluckslotbns9 == 4)) {
			#Playlevel must be 3 lines or greater to spin these reels
			$potluckslotdivd = $potluckslotdivd + 2;
		} elsif (($potluckplaylevel >= 3) && ($potluckslotbns9 == 6)) {
			$potluckslotdivd = $potluckslotdivd + 1.33333333333333333333;
		}
	} elsif ($potluckslotsymbol9 <= 36) {
		$potlucksvslot9 = 4;
	} elsif ($potluckslotsymbol9 <= 40) {
		$potlucksvslot9 = 3;
	} elsif ($potluckslotsymbol9 <= 42) {
		$potlucksvslot9 = 2;
		if (($potluckplaylevel >= 3) && ($potluckslotbns9 == 7)) {
			#Playlevel must be 3 lines or greater to spin these reels
			$potluckslotmltp = $potluckslotmltp + 2;
		}
	} elsif ($potluckslotsymbol9 == 43) {
		$potlucksvslot9 = 1;
	} elsif (($potluckslotsymbol9 == 44) && ($potluckslotdh9 == 1)) {
		$potlucksvslot9 = 'd';
		if (($potluckplaylevel >= 3) && ($potluckslotbns9 == 7)) {
			#Playlevel must be 3 lines or greater to spin these reels
			$potluckslotmltp = $potluckslotmltp + 4;
		}
	} elsif ($potluckslotsymbol9 >= 44) {
		$potlucksvslot9 = 9;			
	} else {
		$potlucksvslot9 = 0;
	}
	
}


					
sub potluckslot1 {
	if ($potluckslot1 eq 'spining') {
		potluckslotspining();
	} elsif ($potluckslot1 eq 'd') {
		potluckslot1dheart1();
	} elsif ($potluckslot1 eq 'd4') {
		potluckslot1dheart1b4();
	} elsif ($potluckslot1 eq 's2') {
		potluckslot1spad1b2();
	} elsif ($potluckslot1 eq 'ch') {
		potluckslot1coin1bh();
	} elsif ($potluckslot1 eq 'sh') {
		potluckslot1coin1bs();
	} elsif ($potluckslot1 == 1) {
		potluckslot1swrd1();
	} elsif ($potluckslot1 == 2) {
		potluckslot1spad1();
	} elsif ($potluckslot1 == 3) {
		potluckslot1clov1();	
	} elsif ($potluckslot1 == 4) {
		potluckslot1heart1();
	} elsif ($potluckslot1 == 5) {
		potluckslot1coin1();
	} elsif ($potluckslot1 == 6) {
		potluckslot1hsho1();
	} elsif ($potluckslot1 == 7) {
		potluckslot1hsho5();
	} elsif ($potluckslot1 == 8) {
		potluckslot1swrd5();
	} elsif ($potluckslot1 == 9) {
		potluckslot1coin5();
	} elsif ($potluckslot1 eq 'x') {
		potluckslot1dheart5();					
	} else {
		potluckslotwhite();
	}

}

sub potluckslot2 {
	if ($potluckslot2 eq 'spining') {
		potluckslotspining();
	} elsif ($potluckslot2 eq 'd') {
		potluckslot1dheart2();
	} elsif ($potluckslot2 eq 'd4') {
		potluckslot1dheart2b4();
	} elsif ($potluckslot2 eq 's2') {
		potluckslot1spad2b2();
	} elsif ($potluckslot2 eq 'ch') {
		potluckslot1coin2bh();
	} elsif ($potluckslot2 eq 'sh') {
		potluckslot1coin2bs();
	} elsif ($potluckslot2 == 1) {
		potluckslot1swrd2();
	} elsif ($potluckslot2 == 2) {
		potluckslot1spad2();
	} elsif ($potluckslot2 == 3) {
		potluckslot1clov2();	
	} elsif ($potluckslot2 == 4) {
		potluckslot1heart2();
	} elsif ($potluckslot2 == 5) {
		potluckslot1coin2();
	} elsif ($potluckslot2 == 6) {
		potluckslot1hsho2();
	} elsif ($potluckslot2 == 7) {
		potluckslot1hsho6();
	} elsif ($potluckslot2 == 8) {
		potluckslot1swrd6();
	} elsif ($potluckslot1 == 9) {
		potluckslot1coin6();
	} elsif ($potluckslot2 eq 'x') {
		potluckslot1dheart6();					
	} else {
		potluckslotwhite();
	}

}

sub potluckslot3 {
	if ($potluckslot3 eq 'spining') {
		potluckslotspining();
	} elsif ($potluckslot3 eq '2xmulti') {
		potluckslot12xmulti3();
	} elsif ($potluckslot3 eq '3xmulti') {
		potluckslot13xmulti3();
	} elsif ($potluckslot3 eq 'd') {
		potluckslot1dheart3();
	} elsif ($potluckslot3 eq 'd4') {
		potluckslot1dheart3b4();	
	} elsif ($potluckslot3 eq 's2') {
		potluckslot1spad3b2();
	} elsif ($potluckslot3 eq 'ch') {
		potluckslot1coin3bh();
	} elsif ($potluckslot3 eq 'sh') {
		potluckslot1coin3bs();
	} elsif ($potluckslot3 == 1) {
		potluckslot1swrd3();
	} elsif ($potluckslot3 == 2) {
		potluckslot1spad3();
	} elsif ($potluckslot3 == 3) {
		potluckslot1clov3();	
	} elsif ($potluckslot3 == 4) {
		potluckslot1heart3();
	} elsif ($potluckslot3 == 5) {
		potluckslot1coin3();
	} elsif ($potluckslot3 == 6) {
		potluckslot1hsho3();			
	} else {
		potluckslotwhite();
	}
}

sub potluckslot4 {
	if ($potluckslot4 eq 'spining') {
		potluckslotspining();
	} elsif ($potluckslot4 eq '2xmulti') {
		potluckslot12xmulti4();
	} elsif ($potluckslot4 eq '3xmulti') {
		potluckslot13xmulti4();
	} elsif ($potluckslot4 eq 'd') {
		potluckslot1dheart4();
	} elsif ($potluckslot4 eq 'd4') {
		potluckslot1dheart4b4();
	} elsif ($potluckslot4 eq 's2') {
		potluckslot1spad4b2();
	} elsif ($potluckslot4 eq 'ch') {
		potluckslot1coin4bh();
	} elsif ($potluckslot4 eq 'sh') {
		potluckslot1coin4bs();
	} elsif ($potluckslot4 == 1) {
		potluckslot1swrd4();
	} elsif ($potluckslot4 == 2) {
		potluckslot1spad4();
	} elsif ($potluckslot4 == 3) {
		potluckslot1clov4();	
	} elsif ($potluckslot4 == 4) {
		potluckslot1heart4();
	} elsif ($potluckslot4 == 5) {
		potluckslot1coin4();
	} elsif ($potluckslot4 == 6) {
		potluckslot1hsho4();			
	} else {
		potluckslotwhite();
	}
}

sub potluckslot5 {
	if ($potluckslot5 eq 'spining') {
		potluckslotspining();
	} elsif ($potluckslot5 eq 'd') {
		potluckslot1dheart5();
	} elsif ($potluckslot5 eq 'd4') {
		potluckslot1dheart5b4();
	} elsif ($potluckslot5 eq 's2') {
		potluckslot1spad5b2();
	} elsif ($potluckslot5 eq 'ch') {
		potluckslot1coin5bh();
	} elsif ($potluckslot5 eq 'sh') {
		potluckslot1coin5bs();
	} elsif ($potluckslot5 == 1) {
		potluckslot1swrd5();
	} elsif ($potluckslot5 == 2) {
		potluckslot1spad5();
	} elsif ($potluckslot5 == 3) {
		potluckslot1clov5();	
	} elsif ($potluckslot5 == 4) {
		potluckslot1heart5();
	} elsif ($potluckslot5 == 5) {
		potluckslot1coin5();
	} elsif ($potluckslot5 == 6) {
		potluckslot1hsho5();
	} elsif ($potluckslot5 == 7) {
		potluckslot1heart1();
	} elsif ($potluckslot5 == 8) {
		potluckslot1clov1();
	} elsif ($potluckslot5 == 9) {
		potluckslot1spad1();
	} elsif ($potluckslot5 eq 'x') {
		potluckslot1coin1();							
	} else {
		potluckslotwhite();
	}
}

sub potluckslot6 {
	if ($potluckslot6 eq 'spining') {
		potluckslotspining();
	} elsif ($potluckslot6 eq 'd') {
		potluckslot1dheart6();
	} elsif ($potluckslot6 eq 'd4') {
		potluckslot1dheart6b4();	
	} elsif ($potluckslot6 eq 's2') {
		potluckslot1spad6b2();
	} elsif ($potluckslot6 eq 'ch') {
		potluckslot1coin6bh();
	} elsif ($potluckslot6 eq 'sh') {
		potluckslot1coin6bs();
	} elsif ($potluckslot6 == 1) {
		potluckslot1swrd6();
	} elsif ($potluckslot6 == 2) {
		potluckslot1spad6();
	} elsif ($potluckslot6 == 3) {
		potluckslot1clov6();	
	} elsif ($potluckslot6 == 4) {
		potluckslot1heart6();
	} elsif ($potluckslot6 == 5) {
		potluckslot1coin6();
	} elsif ($potluckslot6 == 6) {
		potluckslot1hsho6();
	} elsif ($potluckslot6 == 7) {
		potluckslot1heart2();
	} elsif ($potluckslot6 == 8) {
		potluckslot1clov2();
	} elsif ($potluckslot6 == 9) {
		potluckslot1spad2();
	} elsif ($potluckslot6 eq 'x') {
		potluckslot1coin2();					
	} else {
		potluckslotwhite();
	}
}

sub potluckreel1 {
	$potluckreel = 1;
	if ((($potluckreelspin == 9) and ($potluckplaylevel <= 3)) or (($potluckreelspin >= 6) and ($potluckplaylevel >= 4))) {
		$potluckslot1 = 'spining';
		$potluckslot2 = 'spining';
		$potluckslot3 = 'spining';
		$potluckslot4 = 'spining';
		$potluckslot5 = 'spining';
		$potluckslot6 = 'spining';
	} elsif (($potlucksvslot1 == 2) && ($potluckslotbns1 == 7)) {
		$potluckslot1 = 's2';
		$potluckslot2 = 's2';
		$potluckslot3 = 's2';
		$potluckslot4 = 's2';
		$potluckslot5 = 's2';
		$potluckslot6 = 's2';
	} elsif (($potlucksvslot1 == 5) && ($potluckslotbns1 == 4)) {
		$potluckslot1 = 'ch';
		$potluckslot2 = 'ch';
		$potluckslot3 = 'ch';
		$potluckslot4 = 'ch';
		$potluckslot5 = 'ch';
		$potluckslot6 = 'ch';
	} elsif (($potlucksvslot1 == 5) && ($potluckslotbns1 == 6)) {
		$potluckslot1 = 'sh';
		$potluckslot2 = 'sh';
		$potluckslot3 = 'sh';
		$potluckslot4 = 'sh';
		$potluckslot5 = 'sh';
		$potluckslot6 = 'sh';
	} elsif (($potlucksvslot1 eq 'd') && ($potluckslotbns1 == 7)) {
		$potluckslot1 = 'd4';
		$potluckslot2 = 'd4';
		$potluckslot3 = 'd4';
		$potluckslot4 = 'd4';
		$potluckslot5 = 'd4';
		$potluckslot6 = 'd4';
	} else {
		$potluckslot1 = $potlucksvslot1;
		$potluckslot2 = $potlucksvslot1;
		$potluckslot3 = $potlucksvslot1;
		$potluckslot4 = $potlucksvslot1;
		$potluckslot5 = $potlucksvslot1;
		$potluckslot6 = $potlucksvslot1;
	}
	
}

sub potluckreel2 {
	$potluckreel = 2;
	if ((($potluckreelspin >= 8) and ($potluckplaylevel <= 3)) or (($potluckreelspin >= 4) and ($potluckplaylevel >= 4))) {
		$potluckslot1 = 'spining';
		$potluckslot2 = 'spining';
		$potluckslot3 = 'spining';
		$potluckslot4 = 'spining';
		$potluckslot5 = 'spining';
		$potluckslot6 = 'spining';
	} elsif (($potlucksvslot2 == 2) && ($potluckslotbns2 == 7)) {
		$potluckslot1 = 's2';
		$potluckslot2 = 's2';
		if ($potluckslotsymbolX2M == 5) {
			$potluckslot3 = '2xmulti';
			$potluckslot4 = '2xmulti';
		} elsif ($potluckslotsymbolX3M == 12) {
			$potluckslot3 = '3xmulti';
			$potluckslot4 = '3xmulti';	
		} else {
			$potluckslot3 = 's2';
			$potluckslot4 = 's2';
		}
		$potluckslot5 = 's2';
		$potluckslot6 = 's2';
	} elsif (($potlucksvslot2 == 5) && ($potluckslotbns2 == 4)) {
		$potluckslot1 = 'ch';
		$potluckslot2 = 'ch';
		if ($potluckslotsymbolX2M == 5) {
			$potluckslot3 = '2xmulti';
			$potluckslot4 = '2xmulti';
		} elsif ($potluckslotsymbolX3M == 12) {
			$potluckslot3 = '3xmulti';
			$potluckslot4 = '3xmulti';	
		} else {
		$potluckslot3 = 'ch';
		$potluckslot4 = 'ch';
		}
		$potluckslot5 = 'ch';
		$potluckslot6 = 'ch';
	} elsif (($potlucksvslot2 == 5) && ($potluckslotbns2 == 6)) {
		$potluckslot1 = 'sh';
		$potluckslot2 = 'sh';
		if ($potluckslotsymbolX2M == 5) {
			$potluckslot3 = '2xmulti';
			$potluckslot4 = '2xmulti';
		} elsif ($potluckslotsymbolX3M == 12) {
			$potluckslot3 = '3xmulti';
			$potluckslot4 = '3xmulti';	
		} else {
		$potluckslot3 = 'sh';
		$potluckslot4 = 'sh';
		}
		$potluckslot5 = 'sh';
		$potluckslot6 = 'sh';
	} elsif (($potlucksvslot2 eq 'd') && ($potluckslotbns2 == 7)) {
		$potluckslot1 = 'd4';
		$potluckslot2 = 'd4';
		if ($potluckslotsymbolX2M == 5) {
			$potluckslot3 = '2xmulti';
			$potluckslot4 = '2xmulti';
		} elsif ($potluckslotsymbolX3M == 12) {
			$potluckslot3 = '3xmulti';
			$potluckslot4 = '3xmulti';	
		} else {
			$potluckslot3 = 'd4';
			$potluckslot4 = 'd4';
		}
		$potluckslot5 = 'd4';
		$potluckslot6 = 'd4';
	} else {
		$potluckslot1 = $potlucksvslot2;
		$potluckslot2 = $potlucksvslot2;
		if ($potluckslotsymbolX2M == 5) {
			$potluckslot3 = '2xmulti';
			$potluckslot4 = '2xmulti';
		} elsif ($potluckslotsymbolX3M == 12) {
			$potluckslot3 = '3xmulti';
			$potluckslot4 = '3xmulti';	
		} else {
			$potluckslot3 = $potlucksvslot2;
			$potluckslot4 = $potlucksvslot2;
		}
		$potluckslot5 = $potlucksvslot2;
		$potluckslot6 = $potlucksvslot2;
	}
}

sub potluckreel3 {
	$potluckreel = 3;
	if ((($potluckreelspin >= 7) and ($potluckplaylevel <= 3)) or (($potluckreelspin >= 7) and ($potluckplaylevel >= 4))) {
		$potluckslot1 = 'spining';
		$potluckslot2 = 'spining';
		$potluckslot3 = 'spining';
		$potluckslot4 = 'spining';
		$potluckslot5 = 'spining';
		$potluckslot6 = 'spining';
	} elsif (($potlucksvslot3 == 2) && ($potluckslotbns3 == 7)) {
		$potluckslot1 = 's2';
		$potluckslot2 = 's2';
		$potluckslot3 = 's2';
		$potluckslot4 = 's2';
		$potluckslot5 = 's2';
		$potluckslot6 = 's2';
	} elsif (($potlucksvslot3 == 5) && ($potluckslotbns3 == 4)) {
		$potluckslot1 = 'ch';
		$potluckslot2 = 'ch';
		$potluckslot3 = 'ch';
		$potluckslot4 = 'ch';
		$potluckslot5 = 'ch';
		$potluckslot6 = 'ch';
	} elsif (($potlucksvslot3 == 5) && ($potluckslotbns3 == 6)) {
		$potluckslot1 = 'sh';
		$potluckslot2 = 'sh';
		$potluckslot3 = 'sh';
		$potluckslot4 = 'sh';
		$potluckslot5 = 'sh';
		$potluckslot6 = 'sh';
	} elsif (($potlucksvslot3 eq 'd') && ($potluckslotbns3 == 7)) {
		$potluckslot1 = 'd4';
		$potluckslot2 = 'd4';
		$potluckslot3 = 'd4';
		$potluckslot4 = 'd4';
		$potluckslot5 = 'd4';
		$potluckslot6 = 'd4';
	} else {
		$potluckslot1 = $potlucksvslot3;
		$potluckslot2 = $potlucksvslot3;
		$potluckslot3 = $potlucksvslot3;
		$potluckslot4 = $potlucksvslot3;
		$potluckslot5 = $potlucksvslot3;
		$potluckslot6 = $potlucksvslot3;
	}
}

sub potluckreel4 {
	$potluckreel = 4;
	if ((($potluckreelspin >= 6) and (($potluckplaylevel == 2) or ($potluckplaylevel == 3))) or (($potluckreelspin >= 8) and ($potluckplaylevel >= 4))) {
		$potluckslot1 = 'spining';
		$potluckslot2 = 'spining';
		$potluckslot3 = 'spining';
		$potluckslot4 = 'spining';
		$potluckslot5 = 'spining';
		$potluckslot6 = 'spining';
	} elsif (($potlucksvslot4 == 2) && ($potluckslotbns4 == 7)) {
		$potluckslot1 = 's2';
		$potluckslot2 = 's2';
		$potluckslot3 = 's2';
		$potluckslot4 = 's2';
		$potluckslot5 = 's2';
		$potluckslot6 = 's2';
	} elsif (($potlucksvslot4 == 5) && ($potluckslotbns4 == 4)) {
		$potluckslot1 = 'ch';
		$potluckslot2 = 'ch';
		$potluckslot3 = 'ch';
		$potluckslot4 = 'ch';
		$potluckslot5 = 'ch';
		$potluckslot6 = 'ch';
	} elsif (($potlucksvslot4 == 5) && ($potluckslotbns4 == 6)) {
		$potluckslot1 = 'sh';
		$potluckslot2 = 'sh';
		$potluckslot3 = 'sh';
		$potluckslot4 = 'sh';
		$potluckslot5 = 'sh';
		$potluckslot6 = 'sh';
	} elsif (($potlucksvslot4 eq 'd') && ($potluckslotbns4 == 7)) {
		$potluckslot1 = 'd4';
		$potluckslot2 = 'd4';
		$potluckslot3 = 'd4';
		$potluckslot4 = 'd4';
		$potluckslot5 = 'd4';
		$potluckslot6 = 'd4';
	} else {
		$potluckslot1 = $potlucksvslot4;
		$potluckslot2 = $potlucksvslot4;
		$potluckslot3 = $potlucksvslot4;
		$potluckslot4 = $potlucksvslot4;
		$potluckslot5 = $potlucksvslot4;
		$potluckslot6 = $potlucksvslot4;
	}
}

sub potluckreel5 {
	$potluckreel = 5;
	if ((($potluckreelspin >= 5) and (($potluckplaylevel == 2) or ($potluckplaylevel == 3))) or (($potluckreelspin >= 1) and ($potluckplaylevel >= 4))) {
		$potluckslot1 = 'spining';
		$potluckslot2 = 'spining';
		$potluckslot3 = 'spining';
		$potluckslot4 = 'spining';
		$potluckslot5 = 'spining';
		$potluckslot6 = 'spining';
	} elsif (($potlucksvslot5 == 2) && ($potluckslotbns5 == 7)) {
		$potluckslot1 = 's2';
		$potluckslot2 = 's2';
		$potluckslot3 = 's2';
		$potluckslot4 = 's2';
		$potluckslot5 = 's2';
		$potluckslot6 = 's2';
	} elsif (($potlucksvslot5 == 5) && ($potluckslotbns5 == 4)) {
		$potluckslot1 = 'ch';
		$potluckslot2 = 'ch';
		$potluckslot3 = 'ch';
		$potluckslot4 = 'ch';
		$potluckslot5 = 'ch';
		$potluckslot6 = 'ch';
	} elsif (($potlucksvslot5 == 5) && ($potluckslotbns5 == 6)) {
		$potluckslot1 = 'sh';
		$potluckslot2 = 'sh';
		$potluckslot3 = 'sh';
		$potluckslot4 = 'sh';
		$potluckslot5 = 'sh';
		$potluckslot6 = 'sh';
	} elsif (($potlucksvslot5 eq 'd') && ($potluckslotbns5 == 7)) {
		$potluckslot1 = 'd4';
		$potluckslot2 = 'd4';
		$potluckslot3 = 'd4';
		$potluckslot4 = 'd4';
		$potluckslot5 = 'd4';
		$potluckslot6 = 'd4';
	} else {
		$potluckslot1 = $potlucksvslot5;
		$potluckslot2 = $potlucksvslot5;
		$potluckslot3 = $potlucksvslot5;
		$potluckslot4 = $potlucksvslot5;
		$potluckslot5 = $potlucksvslot5;
		$potluckslot6 = $potlucksvslot5;
	}
}

sub potluckreel6 {
	$potluckreel = 6;
	if ((($potluckreelspin >= 4) and (($potluckplaylevel == 2) or ($potluckplaylevel == 3))) or (($potluckreelspin >= 3) and ($potluckplaylevel >= 4))) {
		$potluckslot1 = 'spining';
		$potluckslot2 = 'spining';
		$potluckslot3 = 'spining';
		$potluckslot4 = 'spining';
		$potluckslot5 = 'spining';
		$potluckslot6 = 'spining';
	} elsif (($potlucksvslot6 == 2) && ($potluckslotbns6 == 7)) {
		$potluckslot1 = 's2';
		$potluckslot2 = 's2';
		$potluckslot3 = 's2';
		$potluckslot4 = 's2';
		$potluckslot5 = 's2';
		$potluckslot6 = 's2';
	} elsif (($potlucksvslot6 == 5) && ($potluckslotbns6 == 4)) {
		$potluckslot1 = 'ch';
		$potluckslot2 = 'ch';
		$potluckslot3 = 'ch';
		$potluckslot4 = 'ch';
		$potluckslot5 = 'ch';
		$potluckslot6 = 'ch';
	} elsif (($potlucksvslot6 == 5) && ($potluckslotbns6 == 6)) {
		$potluckslot1 = 'sh';
		$potluckslot2 = 'sh';
		$potluckslot3 = 'sh';
		$potluckslot4 = 'sh';
		$potluckslot5 = 'sh';
		$potluckslot6 = 'sh';
	} elsif (($potlucksvslot6 eq 'd') && ($potluckslotbns6 == 7)) {
		$potluckslot1 = 'd4';
		$potluckslot2 = 'd4';
		$potluckslot3 = 'd4';
		$potluckslot4 = 'd4';
		$potluckslot5 = 'd4';
		$potluckslot6 = 'd4';
	} else {
		$potluckslot1 = $potlucksvslot6;
		$potluckslot2 = $potlucksvslot6;
		$potluckslot3 = $potlucksvslot6;
		$potluckslot4 = $potlucksvslot6;
		$potluckslot5 = $potlucksvslot6;
		$potluckslot6 = $potlucksvslot6;
	}
}

sub potluckreel7 {
	$potluckreel = 7;
	if ((($potluckreelspin >= 3) and ($potluckplaylevel == 3)) or (($potluckreelspin >= 2) and ($potluckplaylevel >= 4))) {
		$potluckslot1 = 'spining';
		$potluckslot2 = 'spining';
		$potluckslot3 = 'spining';
		$potluckslot4 = 'spining';
		$potluckslot5 = 'spining';
		$potluckslot6 = 'spining';
	} elsif (($potlucksvslot7 == 2) && ($potluckslotbns7 == 7)) {
		$potluckslot1 = 's2';
		$potluckslot2 = 's2';
		$potluckslot3 = 's2';
		$potluckslot4 = 's2';
		$potluckslot5 = 's2';
		$potluckslot6 = 's2';
	} elsif (($potlucksvslot7 == 5) && ($potluckslotbns7 == 4)) {
		$potluckslot1 = 'ch';
		$potluckslot2 = 'ch';
		$potluckslot3 = 'ch';
		$potluckslot4 = 'ch';
		$potluckslot5 = 'ch';
		$potluckslot6 = 'ch';
	} elsif (($potlucksvslot7 == 5) && ($potluckslotbns7 == 6)) {
		$potluckslot1 = 'sh';
		$potluckslot2 = 'sh';
		$potluckslot3 = 'sh';
		$potluckslot4 = 'sh';
		$potluckslot5 = 'sh';
		$potluckslot6 = 'sh';
	} elsif (($potlucksvslot7 eq 'd') && ($potluckslotbns7 == 7)) {
		$potluckslot1 = 'd4';
		$potluckslot2 = 'd4';
		$potluckslot3 = 'd4';
		$potluckslot4 = 'd4';
		$potluckslot5 = 'd4';
		$potluckslot6 = 'd4';
	} else {
		$potluckslot1 = $potlucksvslot7;
		$potluckslot2 = $potlucksvslot7;
		$potluckslot3 = $potlucksvslot7;
		$potluckslot4 = $potlucksvslot7;
		$potluckslot5 = $potlucksvslot7;
		$potluckslot6 = $potlucksvslot7;
	}
}

sub potluckreel8 {
	$potluckreel = 8;
	if ((($potluckreelspin >= 2) and ($potluckplaylevel == 3)) or (($potluckreelspin == 9) and ($potluckplaylevel >= 4))) {
		$potluckslot1 = 'spining';
		$potluckslot2 = 'spining';
		$potluckslot3 = 'spining';
		$potluckslot4 = 'spining';
		$potluckslot5 = 'spining';
		$potluckslot6 = 'spining';
	} elsif (($potlucksvslot8 == 2) && ($potluckslotbns8 == 7)) {
		$potluckslot1 = 's2';
		$potluckslot2 = 's2';
		$potluckslot3 = 's2';
		$potluckslot4 = 's2';
		$potluckslot5 = 's2';
		$potluckslot6 = 's2';
	} elsif (($potlucksvslot8 == 5) && ($potluckslotbns8 == 4)) {
		$potluckslot1 = 'ch';
		$potluckslot2 = 'ch';
		$potluckslot3 = 'ch';
		$potluckslot4 = 'ch';
		$potluckslot5 = 'ch';
		$potluckslot6 = 'ch';
	} elsif (($potlucksvslot8 == 5) && ($potluckslotbns8 == 6)) {
		$potluckslot1 = 'sh';
		$potluckslot2 = 'sh';
		$potluckslot3 = 'sh';
		$potluckslot4 = 'sh';
		$potluckslot5 = 'sh';
		$potluckslot6 = 'sh';
	} elsif (($potlucksvslot8 eq 'd') && ($potluckslotbns8 == 7)) {
		$potluckslot1 = 'd4';
		$potluckslot2 = 'd4';
		$potluckslot3 = 'd4';
		$potluckslot4 = 'd4';
		$potluckslot5 = 'd4';
		$potluckslot6 = 'd4';
	} else {
		$potluckslot1 = $potlucksvslot8;
		$potluckslot2 = $potlucksvslot8;
		$potluckslot3 = $potlucksvslot8;
		$potluckslot4 = $potlucksvslot8;
		$potluckslot5 = $potlucksvslot8;
		$potluckslot6 = $potlucksvslot8;
	}
}

sub potluckreel9 {
	$potluckreel = 8;
	if ((($potluckreelspin >= 1) and ($potluckplaylevel == 3)) or (($potluckreelspin >= 5) and ($potluckplaylevel >= 4))) {
		$potluckslot1 = 'spining';
		$potluckslot2 = 'spining';
		$potluckslot3 = 'spining';
		$potluckslot4 = 'spining';
		$potluckslot5 = 'spining';
		$potluckslot6 = 'spining';
	} elsif (($potlucksvslot9 == 2) && ($potluckslotbns9 == 7)) {
		$potluckslot1 = 's2';
		$potluckslot2 = 's2';
		$potluckslot3 = 's2';
		$potluckslot4 = 's2';
		$potluckslot5 = 's2';
		$potluckslot6 = 's2';
	} elsif (($potlucksvslot9 == 5) && ($potluckslotbns9 == 4)) {
		$potluckslot1 = 'ch';
		$potluckslot2 = 'ch';
		$potluckslot3 = 'ch';
		$potluckslot4 = 'ch';
		$potluckslot5 = 'ch';
		$potluckslot6 = 'ch';
	} elsif (($potlucksvslot9 == 5) && ($potluckslotbns9 == 6)) {
		$potluckslot1 = 'sh';
		$potluckslot2 = 'sh';
		$potluckslot3 = 'sh';
		$potluckslot4 = 'sh';
		$potluckslot5 = 'sh';
		$potluckslot6 = 'sh';
	} elsif (($potlucksvslot9 eq 'd') && ($potluckslotbns9 == 7)) {
		$potluckslot1 = 'd4';
		$potluckslot2 = 'd4';
		$potluckslot3 = 'd4';
		$potluckslot4 = 'd4';
		$potluckslot5 = 'd4';
		$potluckslot6 = 'd4';
	} else {
		$potluckslot1 = $potlucksvslot9;
		$potluckslot2 = $potlucksvslot9;
		$potluckslot3 = $potlucksvslot9;
		$potluckslot4 = $potlucksvslot9;
		$potluckslot5 = $potlucksvslot9;
		$potluckslot6 = $potlucksvslot9;
	}
}

sub potluckmid0 {
	print color 'reset';
	print colored('||',"$boldblack on_$bgcblack");
	print color 'reset';
}

sub potluckmid1 {
	print color 'reset';
	print colored('-------',"$boldyellow on_$bgcyellow");
	print color 'reset';
}

sub potluckmid4 {
	print color 'reset';
	print colored('-------------------',"$boldyellow on_$bgcyellow");
	print color 'reset';
}

sub potluckmid2 {
	print color 'reset';
	print colored('--',"$boldyellow on_$bgcyellow");
	print color 'reset';
}

sub potluckmid3 {
	print color 'reset';
	print colored('-',"$boldyellow on_$bgcyellow");
	print color 'reset';
}

sub potluckend0 {
	print color 'reset';
	print colored('---',"$boldyellow on_$bgcyellow");
	print color 'reset';
}

sub potluckendp1 {
	if ($potluckplaylevel >= 1) {
		print colored('1P',"$boldwhite on_$bgcyellow");
	} else {
		print colored('1P',"$boldblack on_$bgcyellow");
	}
}

sub potluckendp2 {
	if ($potluckplaylevel >= 2) {
		print colored('2P',"$boldwhite on_$bgcyellow");
	} else {
		print colored('2P',"$boldblack on_$bgcyellow");
	}
}

sub potluckendp3 {
	if ($potluckplaylevel >= 3) {
		print colored('3P',"$boldwhite on_$bgcyellow");
	} else {
		print colored('3P',"$boldblack on_$bgcyellow");
	}
}

sub potluckendp4 {
	if ($potluckplaylevel >= 4) {
		print colored('4P',"$boldwhite on_$bgcyellow");
	} else {
		print colored('4P',"$boldblack on_$bgcyellow");
	}
}

sub potluckendp5 {
	if ($potluckplaylevel >= 5) {
		print colored('5P',"$boldwhite on_$bgcyellow");
	} else {
		print colored('5P',"$boldblack on_$bgcyellow");
	}
}

sub potluckendp6 {
	if ($potluckplaylevel >= 6) {
		print colored('6P',"$boldwhite on_$bgcyellow");
	} else {
		print colored('6P',"$boldblack on_$bgcyellow");
	}
}

sub potluckendp7 {
	if ($potluckplaylevel >= 7) {
		print colored('7P',"$boldwhite on_$bgcyellow");
	} else {
		print colored('7P',"$boldblack on_$bgcyellow");
	}
}

sub potluckendp8 {
	if ($potluckplaylevel >= 8) {
		print colored('8P',"$boldwhite on_$bgcyellow");
	} else {
		print colored('8P',"$boldblack on_$bgcyellow");
	}
}

sub potluckend1 {
	print color 'reset';
	print colored('|',"$boldblack on_$bgcblack");
	print color 'reset';
}

sub potluckend2 {
	print color 'reset';
	print colored('--',"$boldyellow on_$bgcyellow");
	print color 'reset';
}

sub potluckslotb {
	print color 'reset';
	print colored('I',"$boldwhite on_$bgcwhite");
	print colored(' ',"$black on_$bgcblack");
	print colored('I',"$boldwhite on_$bgcwhite");
	print colored('|',"$boldblack on_$bgcblack");
	print color 'reset';
}

sub potluckslota {
	print color 'reset';
	print colored('III',"$boldwhite on_$bgcwhite");
	print colored('|',"$boldblack on_$bgcblack");
	print color 'reset';
}

sub potluckmulti1wldend0 {
	print color 'reset';
	print colored('Single-Symbol-Wilds',"$white on_$bgcyellow");
	print color 'reset';
}

sub potluckmulti2wldend0 {
	print color 'reset';
	print colored('NA',"$boldblack on_$bgcyellow");
	print colored('-',"$boldyellow on_$bgcyellow");
	print colored('NA',"$boldblack on_$bgcyellow");
	print colored('-',"$boldyellow on_$bgcyellow");
	print colored('8P',"$white on_$bgcyellow");
	print colored('----',"$boldyellow on_$bgcyellow");
	print colored('SWRD',"$boldred on_$bgcyellow");
	print colored('---',"$boldyellow on_$bgcyellow");	
	print color 'reset';
}

sub potluckmulti1end0 {
	print color 'reset';
	print colored('PossibleMultipliers',"$white on_$bgcyellow");
	print color 'reset';
}

sub potluckmulti2end0 {
	print color 'reset';
	print colored('6P',"$white on_$bgcyellow");
	print colored('-',"$boldyellow on_$bgcyellow");
	print colored('7P',"$white on_$bgcyellow");
	print colored('-',"$boldyellow on_$bgcyellow");
	print colored('8P',"$white on_$bgcyellow");
	print colored('------',"$boldyellow on_$bgcyellow");
	print colored('2X',"$boldwhite on_$bgcblack");
	print colored('---',"$boldyellow on_$bgcyellow");
	print color 'reset';
}

sub potluckmulti3end0 {
	print color 'reset';
	print colored('NA',"$boldblack on_$bgcyellow");
	print colored('-',"$boldyellow on_$bgcyellow");
	print colored('NA',"$boldblack on_$bgcyellow");
	print colored('-',"$boldyellow on_$bgcyellow");
	print colored('8P',"$white on_$bgcyellow");
	print colored('------',"$boldyellow on_$bgcyellow");
	print colored('3X',"$boldyellow on_$bgcgreen");
	print colored('---',"$boldyellow on_$bgcyellow");	
	print color 'reset';
}

sub potluckapotluckmoney {
	if ($potluckxP1p eq "ddd") {
		$potluckapotluckmoney = 3000 * $coin;
		$beepnum = 5;
		$potluckstwin = $potluckstwin + 1;
	} elsif ($potluckxP1p eq "111") {
		$potluckapotluckmoney = 900 * $coin;
		$beepnum = 4;
		$potluckstwin = $potluckstwin + 1;
	} elsif ($potluckxP1p eq "222") {
		$potluckapotluckmoney = 650 * $coin;
		$beepnum = 4;
		$potluckstwin = $potluckstwin + 1;
	} elsif ($potluckxP1p eq "333") {
		$potluckapotluckmoney = 300 * $coin;
		$beepnum = 4;
		$potluckstwin = $potluckstwin + 1;
	} elsif ($potluckxP1p eq "444") {
		$potluckapotluckmoney = 100 * $coin;
		$beepnum = 3;
		$potluckstwin = $potluckstwin + 1;
	} elsif ($potluckxP1p eq "555") {
		$potluckapotluckmoney = 30 * $coin;
		$beepnum = 3;
		$potluckstwin = $potluckstwin + 1;
	} elsif ($potluckxP1p eq "666") {
		$potluckapotluckmoney = 10 * $coin;
		$beepnum = 3;
		$potluckstwin = $potluckstwin + 1;													
	} else {
		$potluckapotluckmoney = 0;
		$beepnum = 0;
	}
	
	
	if (($potluckxP1Zp eq "55") and ($potluckxP1p ne "555")) {
		$potluckapotluckmoney = $potluckapotluckmoney + (4 * $coin);
		$beepnum = $beepnum + 2;
		$potluckstwin = $potluckstwin + 1;												
	} else {
		#ZZzzz
	}
	

	if ($potluckplaylevel >= 2) {		
		if ($potluckxP2p eq "ddd") {
			$potluckapotluckmoney = $potluckapotluckmoney + (3000 * $coin);
			$beepnum = $beepnum + 5;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP2p eq "111") {
			$potluckapotluckmoney = $potluckapotluckmoney + (900 * $coin);
			$beepnum = $beepnum + 4;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP2p eq "222") {
			$potluckapotluckmoney = $potluckapotluckmoney + (650 * $coin);
			$beepnum = $beepnum + 4;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP2p eq "333") {
			$potluckapotluckmoney = $potluckapotluckmoney + (300 * $coin);
			$beepnum = $beepnum + 4;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP2p eq "444") {
			$potluckapotluckmoney = $potluckapotluckmoney + (100 * $coin);
			$beepnum = $beepnum + 3;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP2p eq "555") {
			$potluckapotluckmoney = $potluckapotluckmoney + (30 * $coin);
			$beepnum = $beepnum + 3;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP2p eq "666") {
			$potluckapotluckmoney = $potluckapotluckmoney + (10 * $coin);
			$beepnum = $beepnum + 3;
			$potluckstwin = $potluckstwin + 1;													
		} else {
			#NO-THING!!!
		}
		
		
		if (($potluckxP2Zp eq "55") and ($potluckxP2p ne "555")) {
			$potluckapotluckmoney = $potluckapotluckmoney + (4 * $coin);
			$beepnum = $beepnum + 2;
			$potluckstwin = $potluckstwin + 1;												
		} else {
			#ZZzzz
		}
	}
	
	
	if ($potluckplaylevel >= 3) {		
		if ($potluckxP3p eq "ddd") {
			$potluckapotluckmoney = $potluckapotluckmoney + (3000 * $coin);
			$beepnum = $beepnum + 5;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP3p eq "111") {
			$potluckapotluckmoney = $potluckapotluckmoney + (900 * $coin);
			$beepnum = $beepnum + 4;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP3p eq "222") {
			$potluckapotluckmoney = $potluckapotluckmoney + (650 * $coin);
			$beepnum = $beepnum + 4;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP3p eq "333") {
			$potluckapotluckmoney = $potluckapotluckmoney + (300 * $coin);
			$beepnum = $beepnum + 4;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP3p eq "444") {
			$potluckapotluckmoney = $potluckapotluckmoney + (100 * $coin);
			$beepnum = $beepnum + 3;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP3p eq "555") {
			$potluckapotluckmoney = $potluckapotluckmoney + (30 * $coin);
			$beepnum = $beepnum + 3;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP3p eq "666") {
			$potluckapotluckmoney = $potluckapotluckmoney + (10 * $coin);
			$beepnum = $beepnum + 3;
			$potluckstwin = $potluckstwin + 1;													
		} else {
			#NO-THING!!!
		}
		
		
		if (($potluckxP3Zp eq "55") and ($potluckxP3p ne "555")) {
			$potluckapotluckmoney = $potluckapotluckmoney + (4 * $coin);
			$beepnum = $beepnum + 2;
			$potluckstwin = $potluckstwin + 1;												
		} else {
			#ZZzzz
		}
	}	
	
	
	if ($potluckplaylevel >= 4) {		
		if ($potluckxP4p eq "ddd") {
			$potluckapotluckmoney = $potluckapotluckmoney + (3000 * $coin);
			$beepnum = $beepnum + 5;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP4p eq "111") {
			$potluckapotluckmoney = $potluckapotluckmoney + (900 * $coin);
			$beepnum = $beepnum + 4;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP4p eq "222") {
			$potluckapotluckmoney = $potluckapotluckmoney + (650 * $coin);
			$beepnum = $beepnum + 4;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP4p eq "333") {
			$potluckapotluckmoney = $potluckapotluckmoney + (300 * $coin);
			$beepnum = $beepnum + 4;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP4p eq "444") {
			$potluckapotluckmoney = $potluckapotluckmoney + (100 * $coin);
			$beepnum = $beepnum + 3;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP4p eq "555") {
			$potluckapotluckmoney = $potluckapotluckmoney + (30 * $coin);
			$beepnum = $beepnum + 3;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP4p eq "666") {
			$potluckapotluckmoney = $potluckapotluckmoney + (10 * $coin);
			$beepnum = $beepnum + 3;
			$potluckstwin = $potluckstwin + 1;													
		} else {
			#NO-THING!!!
		}
		
		
		if (($potluckxP4Zp eq "55") and ($potluckxP4p ne "555")) {
			$potluckapotluckmoney = $potluckapotluckmoney + (4 * $coin);
			$beepnum = $beepnum + 2;
			$potluckstwin = $potluckstwin + 1;												
		} else {
			#ZZzzz
		}	
	}	
	
	
	if ($potluckplaylevel >= 5) {		
		if ($potluckxP5p eq "ddd") {
			$potluckapotluckmoney = $potluckapotluckmoney + (3000 * $coin);
			$beepnum = $beepnum + 5;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP5p eq "111") {
			$potluckapotluckmoney = $potluckapotluckmoney + (900 * $coin);
			$beepnum = $beepnum + 4;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP5p eq "222") {
			$potluckapotluckmoney = $potluckapotluckmoney + (650 * $coin);
			$beepnum = $beepnum + 4;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP5p eq "333") {
			$potluckapotluckmoney = $potluckapotluckmoney + (300 * $coin);
			$beepnum = $beepnum + 4;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP5p eq "444") {
			$potluckapotluckmoney = $potluckapotluckmoney + (100 * $coin);
			$beepnum = $beepnum + 3;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP5p eq "555") {
			$potluckapotluckmoney = $potluckapotluckmoney + (30 * $coin);
			$beepnum = $beepnum + 3;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP5p eq "666") {
			$potluckapotluckmoney = $potluckapotluckmoney + (10 * $coin);
			$beepnum = $beepnum + 3;
			$potluckstwin = $potluckstwin + 1;													
		} else {
			#NO-THING!!!
		}
		
		
		if (($potluckxP5Zp eq "55") and ($potluckxP5p ne "555")) {
			$potluckapotluckmoney = $potluckapotluckmoney + (4 * $coin);
			$beepnum = $beepnum + 2;
			$potluckstwin = $potluckstwin + 1;												
		} else {
			#ZZzzz
		}
	}
	
	
	if ($potluckplaylevel >= 6) {		
		if ($potluckxP6p eq "ddd") {
			$potluckapotluckmoney = $potluckapotluckmoney + (3000 * $coin);
			$beepnum = $beepnum + 5;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP6p eq "111") {
			$potluckapotluckmoney = $potluckapotluckmoney + (900 * $coin);
			$beepnum = $beepnum + 4;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP6p eq "222") {
			$potluckapotluckmoney = $potluckapotluckmoney + (650 * $coin);
			$beepnum = $beepnum + 4;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP6p eq "333") {
			$potluckapotluckmoney = $potluckapotluckmoney + (300 * $coin);
			$beepnum = $beepnum + 4;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP6p eq "444") {
			$potluckapotluckmoney = $potluckapotluckmoney + (100 * $coin);
			$beepnum = $beepnum + 3;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP6p eq "555") {
			$potluckapotluckmoney = $potluckapotluckmoney + (30 * $coin);
			$beepnum = $beepnum + 3;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP6p eq "666") {
			$potluckapotluckmoney = $potluckapotluckmoney + (10 * $coin);
			$beepnum = $beepnum + 3;
			$potluckstwin = $potluckstwin + 1;													
		} else {
			#NO-THING!!!
		}
		
		
		if (($potluckxP6Zp eq "55") and ($potluckxP6p ne "555")) {
			$potluckapotluckmoney = $potluckapotluckmoney + (4 * $coin);
			$beepnum = $beepnum + 2;
			$potluckstwin = $potluckstwin + 1;												
		} else {
			#ZZzzz
		}
	}
	
	if ($potluckplaylevel >= 7) {		
		if ($potluckxP7p eq "ddd") {
			$potluckapotluckmoney = $potluckapotluckmoney + (3000 * $coin);
			$beepnum = $beepnum + 5;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP7p eq "111") {
			$potluckapotluckmoney = $potluckapotluckmoney + (900 * $coin);
			$beepnum = $beepnum + 4;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP7p eq "222") {
			$potluckapotluckmoney = $potluckapotluckmoney + (650 * $coin);
			$beepnum = $beepnum + 4;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP7p eq "333") {
			$potluckapotluckmoney = $potluckapotluckmoney + (300 * $coin);
			$beepnum = $beepnum + 4;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP7p eq "444") {
			$potluckapotluckmoney = $potluckapotluckmoney + (100 * $coin);
			$beepnum = $beepnum + 3;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP7p eq "555") {
			$potluckapotluckmoney = $potluckapotluckmoney + (30 * $coin);
			$beepnum = $beepnum + 3;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP7p eq "666") {
			$potluckapotluckmoney = $potluckapotluckmoney + (10 * $coin);
			$beepnum = $beepnum + 3;
			$potluckstwin = $potluckstwin + 1;													
		} else {
			#NO-THING!!!
		}
		
		
		if (($potluckxP7Zp eq "55") and ($potluckxP7p ne "555")) {
			$potluckapotluckmoney = $potluckapotluckmoney + (4 * $coin);
			$beepnum = $beepnum + 2;
			$potluckstwin = $potluckstwin + 1;												
		} else {
			#ZZzzz
		}
	}

	if ($potluckplaylevel >= 8) {		
		if ($potluckxP8p eq "ddd") {
			$potluckapotluckmoney = $potluckapotluckmoney + (3000 * $coin);
			$beepnum = $beepnum + 5;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP8p eq "111") {
			$potluckapotluckmoney = $potluckapotluckmoney + (900 * $coin);
			$beepnum = $beepnum + 4;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP8p eq "222") {
			$potluckapotluckmoney = $potluckapotluckmoney + (650 * $coin);
			$beepnum = $beepnum + 4;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP8p eq "333") {
			$potluckapotluckmoney = $potluckapotluckmoney + (300 * $coin);
			$beepnum = $beepnum + 4;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP8p eq "444") {
			$potluckapotluckmoney = $potluckapotluckmoney + (100 * $coin);
			$beepnum = $beepnum + 3;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP8p eq "555") {
			$potluckapotluckmoney = $potluckapotluckmoney + (30 * $coin);
			$beepnum = $beepnum + 3;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP8p eq "666") {
			$potluckapotluckmoney = $potluckapotluckmoney + (10 * $coin);
			$beepnum = $beepnum + 3;
			$potluckstwin = $potluckstwin + 1;													
		} else {
			#NO-THING!!!
		}
		
		if (($potluckxP2p4x1 eq "dddd") or ($potluckxP2p4x1 eq "ddd1") 
			or ($potluckxP2p4x1 eq "dd1d") or ($potluckxP2p4x1 eq "d1dd")
			or ($potluckxP2p4x1 eq "1ddd")) {
			$potluckapotluckmoney = $potluckapotluckmoney + (1000 * $coin);
			$beepnum = $beepnum + 4;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP2p4x1 eq "1111") {
			$potluckapotluckmoney = $potluckapotluckmoney + (450 * $coin);
			$beepnum = $beepnum + 3;
			$potluckstwin = $potluckstwin + 1;
		} elsif (($potluckxP2p4x1 eq "2222") or ($potluckxP2p4x1 eq "2221") 
			or ($potluckxP2p4x1 eq "2212") or ($potluckxP2p4x1 eq "2122")
			or ($potluckxP2p4x1 eq "1222")) {
			$potluckapotluckmoney = $potluckapotluckmoney + (325 * $coin);
			$beepnum = $beepnum + 3;
			$potluckstwin = $potluckstwin + 1;
		} elsif (($potluckxP2p4x1 eq "3333") or ($potluckxP2p4x1 eq "3331") 
			or ($potluckxP2p4x1 eq "3313") or ($potluckxP2p4x1 eq "3133")
			or ($potluckxP2p4x1 eq "1333"))  {
			$potluckapotluckmoney = $potluckapotluckmoney + (150 * $coin);
			$beepnum = $beepnum + 3;
			$potluckstwin = $potluckstwin + 1;
		} elsif (($potluckxP2p4x1 eq "4444") or ($potluckxP2p4x1 eq "4441") 
			or ($potluckxP2p4x1 eq "4414") or ($potluckxP2p4x1 eq "4144")
			or ($potluckxP2p4x1 eq "1444"))  {
			$potluckapotluckmoney = $potluckapotluckmoney + (50 * $coin);
			$beepnum = $beepnum + 2;
			$potluckstwin = $potluckstwin + 1;
		} elsif (($potluckxP2p4x1 eq "5555") or ($potluckxP2p4x1 eq "5551") 
			or ($potluckxP2p4x1 eq "5515") or ($potluckxP2p4x1 eq "5155")
			or ($potluckxP2p4x1 eq "1555"))  {
			$potluckapotluckmoney = $potluckapotluckmoney + (15 * $coin);
			$beepnum = $beepnum + 2;
			$potluckstwin = $potluckstwin + 1;
		} elsif (($potluckxP2p4x1 eq "6666") or ($potluckxP2p4x1 eq "6661") 
			or ($potluckxP2p4x1 eq "6616") or ($potluckxP2p4x1 eq "6166")
			or ($potluckxP2p4x1 eq "1666"))  {
			$potluckapotluckmoney = $potluckapotluckmoney + (5 * $coin);
			$beepnum = $beepnum + 2;
			$potluckstwin = $potluckstwin + 1;													
		} else {
			#NO-THING!!!
		}

		
		if (($potluckxP2p4x2 eq "dddd") or ($potluckxP2p4x2 eq "ddd1") 
			or ($potluckxP2p4x2 eq "dd1d") or ($potluckxP2p4x2 eq "d1dd")
			or ($potluckxP2p4x2 eq "1ddd")) {
			$potluckapotluckmoney = $potluckapotluckmoney + (1000 * $coin);
			$beepnum = $beepnum + 4;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP2p4x2 eq "1111") {
			$potluckapotluckmoney = $potluckapotluckmoney + (450 * $coin);
			$beepnum = $beepnum + 3;
			$potluckstwin = $potluckstwin + 1;
		} elsif (($potluckxP2p4x2 eq "2222") or ($potluckxP2p4x2 eq "2221") 
			or ($potluckxP2p4x2 eq "2212") or ($potluckxP2p4x2 eq "2122")
			or ($potluckxP2p4x2 eq "1222")) {
			$potluckapotluckmoney = $potluckapotluckmoney + (325 * $coin);
			$beepnum = $beepnum + 3;
			$potluckstwin = $potluckstwin + 1;
		} elsif (($potluckxP2p4x2 eq "3333") or ($potluckxP2p4x2 eq "3331") 
			or ($potluckxP2p4x2 eq "3313") or ($potluckxP2p4x2 eq "3133")
			or ($potluckxP2p4x2 eq "1333"))  {
			$potluckapotluckmoney = $potluckapotluckmoney + (150 * $coin);
			$beepnum = $beepnum + 3;
			$potluckstwin = $potluckstwin + 1;
		} elsif (($potluckxP2p4x2 eq "4444") or ($potluckxP2p4x2 eq "4441") 
			or ($potluckxP2p4x2 eq "4414") or ($potluckxP2p4x2 eq "4144")
			or ($potluckxP2p4x2 eq "1444"))  {
			$potluckapotluckmoney = $potluckapotluckmoney + (50 * $coin);
			$beepnum = $beepnum + 2;
			$potluckstwin = $potluckstwin + 1;
		} elsif (($potluckxP2p4x2 eq "5555") or ($potluckxP2p4x2 eq "5551") 
			or ($potluckxP2p4x2 eq "5515") or ($potluckxP2p4x2 eq "5155")
			or ($potluckxP2p4x2 eq "1555"))  {
			$potluckapotluckmoney = $potluckapotluckmoney + (15 * $coin);
			$beepnum = $beepnum + 2;
			$potluckstwin = $potluckstwin + 1;
		} elsif (($potluckxP2p4x2 eq "6666") or ($potluckxP2p4x2 eq "6661") 
			or ($potluckxP2p4x2 eq "6616") or ($potluckxP2p4x2 eq "6166")
			or ($potluckxP2p4x2 eq "1666"))  {
			$potluckapotluckmoney = $potluckapotluckmoney + (5 * $coin);
			$beepnum = $beepnum + 2;
			$potluckstwin = $potluckstwin + 1;													
		} else {
			#NO-THING!!!
		}

		if (($potluckxP3p4x1 eq "dddd") or ($potluckxP3p4x1 eq "ddd1") 
			or ($potluckxP3p4x1 eq "dd1d") or ($potluckxP3p4x1 eq "d1dd")
			or ($potluckxP3p4x1 eq "1ddd")) {
			$potluckapotluckmoney = $potluckapotluckmoney + (1000 * $coin);
			$beepnum = $beepnum + 4;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP3p4x1 eq "1111") {
			$potluckapotluckmoney = $potluckapotluckmoney + (450 * $coin);
			$beepnum = $beepnum + 3;
			$potluckstwin = $potluckstwin + 1;
		} elsif (($potluckxP3p4x1 eq "2222") or ($potluckxP3p4x1 eq "2221") 
			or ($potluckxP3p4x1 eq "2212") or ($potluckxP3p4x1 eq "2122")
			or ($potluckxP3p4x1 eq "1222")) {
			$potluckapotluckmoney = $potluckapotluckmoney + (325 * $coin);
			$beepnum = $beepnum + 3;
			$potluckstwin = $potluckstwin + 1;
		} elsif (($potluckxP3p4x1 eq "3333") or ($potluckxP3p4x1 eq "3331") 
			or ($potluckxP3p4x1 eq "3313") or ($potluckxP3p4x1 eq "3133")
			or ($potluckxP3p4x1 eq "1333"))  {
			$potluckapotluckmoney = $potluckapotluckmoney + (150 * $coin);
			$beepnum = $beepnum + 3;
			$potluckstwin = $potluckstwin + 1;
		} elsif (($potluckxP3p4x1 eq "4444") or ($potluckxP3p4x1 eq "4441") 
			or ($potluckxP3p4x1 eq "4414") or ($potluckxP3p4x1 eq "4144")
			or ($potluckxP3p4x1 eq "1444"))  {
			$potluckapotluckmoney = $potluckapotluckmoney + (50 * $coin);
			$beepnum = $beepnum + 2;
			$potluckstwin = $potluckstwin + 1;
		} elsif (($potluckxP3p4x1 eq "5555") or ($potluckxP3p4x1 eq "5551") 
			or ($potluckxP3p4x1 eq "5515") or ($potluckxP3p4x1 eq "5155")
			or ($potluckxP3p4x1 eq "1555"))  {
			$potluckapotluckmoney = $potluckapotluckmoney + (15 * $coin);
			$beepnum = $beepnum + 2;
			$potluckstwin = $potluckstwin + 1;
		} elsif (($potluckxP3p4x1 eq "6666") or ($potluckxP3p4x1 eq "6661") 
			or ($potluckxP3p4x1 eq "6616") or ($potluckxP3p4x1 eq "6166")
			or ($potluckxP3p4x1 eq "1666"))  {
			$potluckapotluckmoney = $potluckapotluckmoney + (5 * $coin);
			$beepnum = $beepnum + 2;
			$potluckstwin = $potluckstwin + 1;													
		} else {
			#NO-THING!!!
		}
		
		if (($potluckxP3p4x2 eq "dddd") or ($potluckxP3p4x2 eq "ddd1") 
			or ($potluckxP3p4x2 eq "dd1d") or ($potluckxP3p4x2 eq "d1dd")
			or ($potluckxP3p4x2 eq "1ddd")) {
			$potluckapotluckmoney = $potluckapotluckmoney + (1000 * $coin);
			$beepnum = $beepnum + 4;
			$potluckstwin = $potluckstwin + 1;
		} elsif ($potluckxP3p4x2 eq "1111") {
			$potluckapotluckmoney = $potluckapotluckmoney + (450 * $coin);
			$beepnum = $beepnum + 3;
			$potluckstwin = $potluckstwin + 1;
		} elsif (($potluckxP3p4x2 eq "2222") or ($potluckxP3p4x2 eq "2221") 
			or ($potluckxP3p4x2 eq "2212") or ($potluckxP3p4x2 eq "2122")
			or ($potluckxP3p4x2 eq "1222")) {
			$potluckapotluckmoney = $potluckapotluckmoney + (325 * $coin);
			$beepnum = $beepnum + 3;
			$potluckstwin = $potluckstwin + 1;
		} elsif (($potluckxP3p4x2 eq "3333") or ($potluckxP3p4x2 eq "3331") 
			or ($potluckxP3p4x2 eq "3313") or ($potluckxP3p4x2 eq "3133")
			or ($potluckxP3p4x2 eq "1333"))  {
			$potluckapotluckmoney = $potluckapotluckmoney + (150 * $coin);
			$beepnum = $beepnum + 3;
			$potluckstwin = $potluckstwin + 1;
		} elsif (($potluckxP3p4x2 eq "4444") or ($potluckxP3p4x2 eq "4441") 
			or ($potluckxP3p4x2 eq "4414") or ($potluckxP3p4x2 eq "4144")
			or ($potluckxP3p4x2 eq "1444"))  {
			$potluckapotluckmoney = $potluckapotluckmoney + (50 * $coin);
			$beepnum = $beepnum + 2;
			$potluckstwin = $potluckstwin + 1;
		} elsif (($potluckxP3p4x2 eq "5555") or ($potluckxP3p4x2 eq "5551") 
			or ($potluckxP3p4x2 eq "5515") or ($potluckxP3p4x2 eq "5155")
			or ($potluckxP3p4x2 eq "1555"))  {
			$potluckapotluckmoney = $potluckapotluckmoney + (15 * $coin);
			$beepnum = $beepnum + 2;
			$potluckstwin = $potluckstwin + 1;
		} elsif (($potluckxP3p4x2 eq "6666") or ($potluckxP3p4x2 eq "6661") 
			or ($potluckxP3p4x2 eq "6616") or ($potluckxP3p4x2 eq "6166")
			or ($potluckxP3p4x2 eq "1666"))  {
			$potluckapotluckmoney = $potluckapotluckmoney + (5 * $coin);
			$beepnum = $beepnum + 2;
			$potluckstwin = $potluckstwin + 1;													
		} else {
			#NO-THING!!!
		}
		
		if (($potluckxP8Zp eq "55") and ($potluckxP8p ne "555")) {
			$potluckapotluckmoney = $potluckapotluckmoney + (4 * $coin);
			$beepnum = $beepnum + 2;
			$potluckstwin = $potluckstwin + 1;												
		} else {
			#ZZzzz
		}

		if ($potluckxP8p eq '1dd'){ plkwind();
		} if ($potluckxP8p eq 'd1d'){ plkwind();
		} if ($potluckxP8p eq 'dd1'){ plkwind();
		} if ($potluckxP7p eq '1dd'){ plkwind();
		} if ($potluckxP7p eq 'd1d'){ plkwind();
		} if ($potluckxP7p eq 'dd1'){ plkwind();
		} if ($potluckxP6p eq '1dd'){ plkwind();
		} if ($potluckxP6p eq 'd1d'){ plkwind();
		} if ($potluckxP6p eq 'dd1'){ plkwind();
		} if ($potluckxP5p eq '1dd'){ plkwind();
		} if ($potluckxP5p eq 'd1d'){ plkwind();
		} if ($potluckxP5p eq 'dd1'){ plkwind();
		} if ($potluckxP4p eq '1dd'){ plkwind();
		} if ($potluckxP4p eq 'd1d'){ plkwind();
		} if ($potluckxP4p eq 'dd1'){ plkwind();
		} if ($potluckxP3p eq '1dd'){ plkwind();
		} if ($potluckxP3p eq 'd1d'){ plkwind();
		} if ($potluckxP3p eq 'dd1'){ plkwind();
		} if ($potluckxP2p eq '1dd'){ plkwind();
		} if ($potluckxP2p eq 'd1d'){ plkwind();
		} if ($potluckxP2p eq 'dd1'){ plkwind();
		} if ($potluckxP1p eq '1dd'){ plkwind();
		} if ($potluckxP1p eq 'd1d'){ plkwind();
		} if ($potluckxP1p eq 'dd1') {
			plkwind();
		#1s absent as redundant
		#2s
		} if ($potluckxP8p eq '122'){ plkwin2();
		} if ($potluckxP8p eq '212'){ plkwin2();
		} if ($potluckxP8p eq '221'){ plkwin2();
		} if ($potluckxP7p eq '122'){ plkwin2();
		} if ($potluckxP7p eq '212'){ plkwin2();
		} if ($potluckxP7p eq '221'){ plkwin2();
		} if ($potluckxP6p eq '122'){ plkwin2();
		} if ($potluckxP6p eq '212'){ plkwin2();
		} if ($potluckxP6p eq '221'){ plkwin2();
		} if ($potluckxP5p eq '122'){ plkwin2();
		} if ($potluckxP5p eq '212'){ plkwin2();
		} if ($potluckxP5p eq '221'){ plkwin2();
		} if ($potluckxP4p eq '122'){ plkwin2();
		} if ($potluckxP4p eq '212'){ plkwin2();
		} if ($potluckxP4p eq '221'){ plkwin2();
		} if ($potluckxP3p eq '122'){ plkwin2();
		} if ($potluckxP3p eq '212'){ plkwin2();
		} if ($potluckxP3p eq '221'){ plkwin2();
		} if ($potluckxP2p eq '122'){ plkwin2();
		} if ($potluckxP2p eq '212'){ plkwin2();
		} if ($potluckxP2p eq '221'){ plkwin2();
		} if ($potluckxP1p eq '122'){ plkwin2();
		} if ($potluckxP1p eq '212'){ plkwin2();
		} if ($potluckxP1p eq '221') {
			plkwin2();
		#3s
		} if ($potluckxP8p eq '133'){ plkwin3();
		} if ($potluckxP8p eq '313'){ plkwin3();
		} if ($potluckxP8p eq '331'){ plkwin3();
		} if ($potluckxP7p eq '133'){ plkwin3();
		} if ($potluckxP7p eq '313'){ plkwin3();
		} if ($potluckxP7p eq '331'){ plkwin3();
		} if ($potluckxP6p eq '133'){ plkwin3();
		} if ($potluckxP6p eq '313'){ plkwin3();
		} if ($potluckxP6p eq '331'){ plkwin3();
		} if ($potluckxP5p eq '133'){ plkwin3();
		} if ($potluckxP5p eq '313'){ plkwin3();
		} if ($potluckxP5p eq '331'){ plkwin3();
		} if ($potluckxP4p eq '133'){ plkwin3();
		} if ($potluckxP4p eq '313'){ plkwin3();
		} if ($potluckxP4p eq '331'){ plkwin3();
		} if ($potluckxP3p eq '133'){ plkwin3();
		} if ($potluckxP3p eq '313'){ plkwin3();
		} if ($potluckxP3p eq '331'){ plkwin3();
		} if ($potluckxP2p eq '133'){ plkwin3();
		} if ($potluckxP2p eq '313'){ plkwin3();
		} if ($potluckxP2p eq '331'){ plkwin3();
		} if ($potluckxP1p eq '133'){ plkwin3();
		} if ($potluckxP1p eq '313'){ plkwin3();
		} if ($potluckxP1p eq '331') {
			plkwin3();
		#4s
		} if ($potluckxP8p eq '144'){ plkwin4();
		} if ($potluckxP8p eq '414'){ plkwin4();
		} if ($potluckxP8p eq '441'){ plkwin4();
		} if ($potluckxP7p eq '144'){ plkwin4();
		} if ($potluckxP7p eq '414'){ plkwin4();
		} if ($potluckxP7p eq '441'){ plkwin4();
		} if ($potluckxP6p eq '144'){ plkwin4();
		} if ($potluckxP6p eq '414'){ plkwin4();
		} if ($potluckxP6p eq '441'){ plkwin4();
		} if ($potluckxP5p eq '144'){ plkwin4();
		} if ($potluckxP5p eq '414'){ plkwin4();
		} if ($potluckxP5p eq '441'){ plkwin4();
		} if ($potluckxP4p eq '144'){ plkwin4();
		} if ($potluckxP4p eq '414'){ plkwin4();
		} if ($potluckxP4p eq '441'){ plkwin4();
		} if ($potluckxP3p eq '144'){ plkwin4();
		} if ($potluckxP3p eq '414'){ plkwin4();
		} if ($potluckxP3p eq '441'){ plkwin4();
		} if ($potluckxP2p eq '144'){ plkwin4();
		} if ($potluckxP2p eq '414'){ plkwin4();
		} if ($potluckxP2p eq '441'){ plkwin4();
		} if ($potluckxP1p eq '144'){ plkwin4();
		} if ($potluckxP1p eq '414'){ plkwin4();
		} if ($potluckxP1p eq '441') {
			plkwin4();
		
		#5s
		} if ($potluckxP8p eq '155'){ plkwin5();
		} if ($potluckxP8p eq '515'){ plkwin5();
		} if ($potluckxP8p eq '551'){ plkwin5();
		} if ($potluckxP7p eq '155'){ plkwin5();
		} if ($potluckxP7p eq '515'){ plkwin5();
		} if ($potluckxP7p eq '551'){ plkwin5();
		} if ($potluckxP6p eq '155'){ plkwin5();
		} if ($potluckxP6p eq '515'){ plkwin5();
		} if ($potluckxP6p eq '551'){ plkwin5();
		} if ($potluckxP5p eq '155'){ plkwin5();
		} if ($potluckxP5p eq '515'){ plkwin5();
		} if ($potluckxP5p eq '551'){ plkwin5();
		} if ($potluckxP4p eq '155'){ plkwin5();
		} if ($potluckxP4p eq '515'){ plkwin5();
		} if ($potluckxP4p eq '551'){ plkwin5();
		} if ($potluckxP3p eq '155'){ plkwin5();
		} if ($potluckxP3p eq '515'){ plkwin5();
		} if ($potluckxP3p eq '551'){ plkwin5();
		} if ($potluckxP2p eq '155'){ plkwin5();
		} if ($potluckxP2p eq '515'){ plkwin5();
		} if ($potluckxP2p eq '551'){ plkwin5();
		} if ($potluckxP1p eq '155'){ plkwin5();
		} if ($potluckxP1p eq '515'){ plkwin5();
		} if ($potluckxP1p eq '551') {
			plkwin5();
		#6
		} if ($potluckxP8p eq '166'){ plkwin6();
		} if ($potluckxP8p eq '616'){ plkwin6();
		} if ($potluckxP8p eq '661'){ plkwin6();
		} if ($potluckxP7p eq '166'){ plkwin6();
		} if ($potluckxP7p eq '616'){ plkwin6();
		} if ($potluckxP7p eq '661'){ plkwin6();
		} if ($potluckxP6p eq '166'){ plkwin6();
		} if ($potluckxP6p eq '616'){ plkwin6();
		} if ($potluckxP6p eq '661'){ plkwin6();
		} if ($potluckxP5p eq '166'){ plkwin6();
		} if ($potluckxP5p eq '616'){ plkwin6();
		} if ($potluckxP5p eq '661'){ plkwin6();
		} if ($potluckxP4p eq '166'){ plkwin6();
		} if ($potluckxP4p eq '616'){ plkwin6();
		} if ($potluckxP4p eq '661'){ plkwin6();
		} if ($potluckxP3p eq '166'){ plkwin6();
		} if ($potluckxP3p eq '616'){ plkwin6();
		} if ($potluckxP3p eq '661'){ plkwin6();
		} if ($potluckxP2p eq '166'){ plkwin6();
		} if ($potluckxP2p eq '616'){ plkwin6();
		} if ($potluckxP2p eq '661'){ plkwin6();
		} if ($potluckxP1p eq '166'){ plkwin6();
		} if ($potluckxP1p eq '616'){ plkwin6();
		} if ($potluckxP1p eq '661') {
			plkwin6();
		} #End.
	}

	if ($potluckapotluckmoney == 0) {
		$potluckstlose = $potluckstlose + 1;
	} else {
		if ($potluckslotmltp > 0) {
			$potluckapotluckmoney = ($potluckapotluckmoney * $potluckslotmltp);
		}
		
		if ($potluckslotsymbolX2M == 5) {
			$potluckapotluckmoney = ($potluckapotluckmoney * 2);
		} elsif ($potluckslotsymbolX3M == 12) {
			$potluckapotluckmoney = ($potluckapotluckmoney * 3);
		}
		
		#Here we apply the reductive multipliers, if any
		if (($potluckslotdivd > 0) && ($potluckapotluckmoney > 0)) {
			$potluckapotluckmoney = ($potluckapotluckmoney / $potluckslotdivd);
			$potluckapotluckmoney  = sprintf("%.0f", $potluckapotluckmoney  ); #make sure full number;
		}
	}
}

sub plkwind {
	$potluckapotluckmoney = $potluckapotluckmoney + (3000 * $coin);
	$beepnum = $beepnum + 5;
	$potluckstwin = $potluckstwin + 1;
}

sub plkwin2 {
	$potluckapotluckmoney = $potluckapotluckmoney + (650 * $coin);
	$beepnum = $beepnum + 4;
	$potluckstwin = $potluckstwin + 1;
}

sub plkwin3 {
	$potluckapotluckmoney = $potluckapotluckmoney + (300 * $coin);
	$beepnum = $beepnum + 4;
	$potluckstwin = $potluckstwin + 1;
}

sub plkwin4 {
	$potluckapotluckmoney = $potluckapotluckmoney + (100 * $coin);
	$beepnum = $beepnum + 3;
	$potluckstwin = $potluckstwin + 1;
}

sub plkwin5 {
	$potluckapotluckmoney = $potluckapotluckmoney + (30 * $coin);
	$beepnum = $beepnum + 3;
	$potluckstwin = $potluckstwin + 1;
}


sub plkwin6 {
	$potluckapotluckmoney = $potluckapotluckmoney + (10 * $coin);
	$beepnum = $beepnum + 3;
	$potluckstwin = $potluckstwin + 1;
}
		
sub potluckmainscreen {
	print colored('/------------------------------------------------------------------------------\\',"$boldblack on_$bgcblack"); print"\n";	
	potluckend1();	print colored('      ',"$boldblack on_$bgcyellow");
	print colored('P',"$boldgreen on_$bgcyellow");
	print colored('o',"$boldwhite on_$bgcyellow"); 
	print colored('t',"$boldgreen on_$bgcyellow");
	print colored('L',"$boldwhite on_$bgcyellow");
	print colored('u',"$boldgreen on_$bgcyellow");
	print colored('c',"$boldwhite on_$bgcyellow");
	print colored('k',"$boldgreen on_$bgcyellow");
	print colored('      C  = Return To Casino Menu   EXIT = quit                   ',"$boldyellow on_$bgcyellow"); potluckend1();
	print"\n";

	potluckend1();	print colored('                   1P = 1 Token  2P = 2 Tokens  3P = 3 Tokens....8P = 8 Tokens',"$boldyellow on_$bgcyellow"); potluckend1(); print"\n";
	print colored('|------------------------------------------------------------------------------|',"$boldblack on_$bgcblack"); print"\n";	

	potluckend1(); print colored('DHRT',"$magenta on_$bgcyellow");
	potluckmid3(); print colored('DHRT',"$magenta on_$bgcyellow");
	potluckmid3(); print colored('DHRT',"$magenta on_$bgcyellow");
	print colored('=3k',"$white on_$bgcyellow");
	potluckendp4(); potluckmid2(); potluckmid1(); potluckendp6(); potluckmid1(); potluckmid2(); potluckmid1(); potluckendp7(); potluckmid1(); potluckmid2(); potluckmid1(); potluckendp8(); potluckmid2(); potluckmid1();  potluckendp5(); potluckmid3(); potluckend1(); print"\n";
	
	if ($potluckplaylevel >= 8) {
	potluckend1(); potluckmid3(); print colored('DHRT',"$magenta on_$bgcyellow");
	potluckmid3(); print colored('x4',"$magenta on_$bgcyellow");
	potluckmid3(); print colored('BOX',"$magenta on_$bgcyellow");
	potluckmid3(); print colored('=1k',"$white on_$bgcyellow");
	} else {
	potluckend1(); potluckmid3(); print colored('DHRT',"$boldblack on_$bgcyellow");
	potluckmid3(); print colored('x4',"$boldblack on_$bgcyellow");
	potluckmid3(); print colored('BOX',"$boldblack on_$bgcyellow");
	potluckmid3(); print colored('=1k',"$boldblack on_$bgcyellow");
	}
	potluckend0();
	print colored('||================||================||================||',"$boldblack on_$bgcblack"); potluckend0(); potluckend1(); print"\n";
	
	potluckend1(); print colored('SWRD',"$boldred on_$bgcyellow");
	potluckmid3(); print colored('SWRD',"$boldred on_$bgcyellow");
	potluckmid3(); print colored('SWRD',"$boldred on_$bgcyellow");
	print colored('=900',"$white on_$bgcyellow"); potluckmid3();
	potluckmid0(); potluckreel7(); sep; potluckslot1(); sep; potluckmid0(); potluckreel8(); sep; potluckslot1(); sep; potluckmid0(); potluckreel9(); sep; potluckslot1(); sep; potluckmid0(); potluckend0(); potluckend1(); print"\n";
	
	
	if ($potluckplaylevel >= 8) {
	potluckend1(); potluckmid3(); print colored('SWRD',"$boldred on_$bgcyellow");
	potluckmid3(); print colored('x4',"$boldred on_$bgcyellow");
	potluckmid3(); print colored('BOX',"$boldred on_$bgcyellow");
	potluckmid3(); print colored('=450',"$white on_$bgcyellow");
	} else {
	potluckend1(); potluckmid3(); print colored('SWRD',"$boldblack on_$bgcyellow");
	potluckmid3(); print colored('x4',"$boldblack on_$bgcyellow");
	potluckmid3(); print colored('BOX',"$boldblack on_$bgcyellow");
	potluckmid3(); print colored('=450',"$boldblack on_$bgcyellow");
	}
	potluckmid3(); potluckmid3(); potluckmid0(); potluckreel7(); sep; potluckslot2(); sep; potluckmid0(); potluckreel8(); sep; potluckslot2(); sep; potluckmid0(); potluckreel9(); sep; potluckslot2(); sep; potluckmid0(); potluckend0(); potluckend1(); print"\n";
	
	potluckend1(); print colored('SPAD',"$black on_$bgcyellow"); 
	potluckmid3(); print colored('SPAD',"$black on_$bgcyellow");
	potluckmid3(); print colored('SPAD',"$black on_$bgcyellow");
	print colored('=650',"$white on_$bgcyellow"); potluckmid3();
	potluckmid0(); potluckreel7(); sep; potluckslot3(); sep; potluckmid0(); potluckreel8(); sep; potluckslot3(); sep; potluckmid0(); potluckreel9(); sep; potluckslot3(); sep; potluckmid0(); potluckend0(); potluckend1(); print"\n";
	
	if ($potluckplaylevel >= 8) {
	potluckend1(); potluckmid3(); print colored('SPAD',"$black on_$bgcyellow");
	potluckmid3(); print colored('x4',"$black on_$bgcyellow");
	potluckmid3(); print colored('BOX',"$black on_$bgcyellow");
	potluckmid3(); print colored('=325',"$white on_$bgcyellow");
	} else {
	potluckend1(); potluckmid3(); print colored('SPAD',"$boldblack on_$bgcyellow");
	potluckmid3(); print colored('x4',"$boldblack on_$bgcyellow");
	potluckmid3(); print colored('BOX',"$boldblack on_$bgcyellow");
	potluckmid3(); print colored('=325',"$boldblack on_$bgcyellow");
	}
	potluckendp3(); potluckmid0(); potluckreel7(); sep; potluckslot4(); sep; potluckmid0(); potluckreel8(); sep; potluckslot4(); sep; potluckmid0(); potluckreel9(); sep; potluckslot4(); sep; potluckmid0(); potluckend0(); potluckend1(); print"\n";
	
	potluckend1(); print colored('CLOV',"$green on_$bgcyellow"); 
	potluckmid3(); print colored('CLOV',"$green on_$bgcyellow"); 
	potluckmid3(); print colored('CLOV',"$green on_$bgcyellow"); 
	print colored('=300',"$white on_$bgcyellow"); potluckmid3();
	potluckmid0(); potluckreel7(); sep; potluckslot5(); sep; potluckmid0(); potluckreel8(); sep; potluckslot5(); sep; potluckmid0(); potluckreel9(); sep; potluckslot5(); sep; potluckmid0(); potluckend0(); potluckend1(); print"\n";
	
	if ($potluckplaylevel >= 8) {
	potluckend1(); potluckmid3(); print colored('CLOV',"$green on_$bgcyellow");
	potluckmid3(); print colored('x4',"$green on_$bgcyellow");
	potluckmid3(); print colored('BOX',"$green on_$bgcyellow");
	potluckmid3(); print colored('=150',"$white on_$bgcyellow");
	} else {
	potluckend1(); potluckmid3(); print colored('CLOV',"$boldblack on_$bgcyellow");
	potluckmid3(); print colored('x4',"$boldblack on_$bgcyellow");
	potluckmid3(); print colored('BOX',"$boldblack on_$bgcyellow");
	potluckmid3(); print colored('=150',"$boldblack on_$bgcyellow");
	}
	potluckmid3(); potluckmid3(); potluckmid0(); potluckreel7(); sep; potluckslot6(); sep; potluckmid0(); potluckreel8(); sep; potluckslot6(); sep; potluckmid0(); potluckreel9(); sep; potluckslot6(); sep; potluckmid0(); potluckend0(); potluckend1(); print"\n";
	
	potluckend1(); print colored('HERT',"$red on_$bgcyellow");
	potluckmid3(); print colored('HERT',"$red on_$bgcyellow");
	potluckmid3(); print colored('HERT',"$red on_$bgcyellow"); 
	print colored('=100',"$white on_$bgcyellow"); potluckmid3();
	print colored('||================||================||================||',"$boldblack on_$bgcblack"); potluckend0(); potluckend1(); print"\n";

	if ($potluckplaylevel >= 8) {
	potluckend1(); potluckmid3(); print colored('HERT',"$red on_$bgcyellow");
	potluckmid3(); print colored('x4',"$red on_$bgcyellow");
	potluckmid3(); print colored('BOX',"$red on_$bgcyellow");
	potluckmid3(); print colored('=50',"$white on_$bgcyellow");
	} else {
	potluckend1(); potluckmid3(); print colored('HERT',"$boldblack on_$bgcyellow");
	potluckmid3(); print colored('x4',"$boldblack on_$bgcyellow");
	potluckmid3(); print colored('BOX',"$boldblack on_$bgcyellow");
	potluckmid3(); print colored('=50',"$boldblack on_$bgcyellow");
	}
	potluckmid3(); potluckmid3(); potluckmid3(); potluckmid0(); potluckreel1(); sep; potluckslot1(); sep; potluckmid0(); potluckreel2(); sep; potluckslot1(); sep; potluckmid0(); potluckreel3(); sep; potluckslot1(); sep; potluckmid0(); potluckend0(); potluckend1(); print"\n";
	
	potluckend1(); print colored('COIN',"$boldwhite on_$bgcyellow");
	potluckmid3(); print colored('COIN',"$boldwhite on_$bgcyellow");
	potluckmid3(); print colored('COIN',"$boldwhite on_$bgcyellow"); 
	print colored('=30',"$white on_$bgcyellow"); potluckmid2();
        potluckmid0(); potluckreel1(); sep; potluckslot2(); sep; potluckmid0(); potluckreel2(); sep; potluckslot2(); sep; potluckmid0(); potluckreel3(); sep; potluckslot2(); sep; potluckmid0(); potluckend0(); potluckend1(); print"\n";
	
	if ($potluckplaylevel >= 8) {
	potluckend1(); potluckmid3(); print colored('COIN',"$boldwhite on_$bgcyellow");
	potluckmid3(); print colored('x4',"$boldwhite on_$bgcyellow");
	potluckmid3(); print colored('BOX',"$boldwhite on_$bgcyellow");
	potluckmid3(); print colored('=15',"$white on_$bgcyellow");
	} else {
	potluckend1(); potluckmid3(); print colored('COIN',"$boldblack on_$bgcyellow");
	potluckmid3(); print colored('x4',"$boldblack on_$bgcyellow");
	potluckmid3(); print colored('BOX',"$boldblack on_$bgcyellow");
	potluckmid3(); print colored('=15',"$boldblack on_$bgcyellow");
	}
	potluckmid3(); potluckmid3(); potluckmid3(); potluckmid0(); potluckreel1(); sep; potluckslot3(); sep; potluckmid0(); potluckreel2(); sep; potluckslot3(); sep; potluckmid0(); potluckreel3(); sep; potluckslot3(); sep; potluckmid0(); potluckend0(); potluckend1(); print"\n";
	
	potluckend1(); print colored('SHOE',"$boldyellow on_$bgcyellow");
	potluckmid3(); print colored('SHOE',"$boldyellow on_$bgcyellow");
	potluckmid3(); print colored('SHOE',"$boldyellow on_$bgcyellow"); 
	print colored('=10',"$white on_$bgcyellow");
	potluckendp1(); potluckmid0(); potluckreel1(); sep; potluckslot4(); sep; potluckmid0(); potluckreel2(); sep; potluckslot4(); sep; potluckmid0(); potluckreel3(); sep; potluckslot4(); sep; potluckmid0(); potluckend0(); potluckend1(); print"\n";
	
	if ($potluckplaylevel >= 8) {
	potluckend1(); potluckmid3(); print colored('SHOE',"$boldyellow on_$bgcyellow");
	potluckmid3(); print colored('x4',"$boldyellow on_$bgcyellow");
	potluckmid3(); print colored('BOX',"$boldyellow on_$bgcyellow");
	potluckmid3(); print colored('=5',"$white on_$bgcyellow");
	} else {
	potluckend1(); potluckmid3(); print colored('SHOE',"$boldblack on_$bgcyellow");
	potluckmid3(); print colored('x4',"$boldblack on_$bgcyellow");
	potluckmid3(); print colored('BOX',"$boldblack on_$bgcyellow");
	potluckmid3(); print colored('=5',"$boldblack on_$bgcyellow");
	}
	potluckmid3(); potluckmid3(); potluckmid3(); potluckmid3(); potluckmid0(); potluckreel1(); sep; potluckslot5(); sep; potluckmid0(); potluckreel2(); sep; potluckslot5(); sep; potluckmid0(); potluckreel3(); sep; potluckslot5(); sep; potluckmid0(); potluckend0(); potluckend1(); print"\n";
	
	potluckend1(); print colored('COIN',"$boldwhite on_$bgcyellow");
	potluckmid3(); print colored('COIN',"$boldwhite on_$bgcyellow"); 
	potluckmid3(); print colored('ANY',"$white on_$bgcyellow"); 
	potluckmid3(); print colored('=4',"$white on_$bgcyellow"); potluckend0();
	potluckmid0(); potluckreel1(); sep; potluckslot6(); sep; potluckmid0(); potluckreel2(); sep; potluckslot6(); sep; potluckmid0(); potluckreel3(); sep; potluckslot6(); sep; potluckmid0(); potluckend0(); potluckend1(); print"\n";
	potluckend1(); potluckmid4(); print colored('||================||================||================||',"$boldblack on_$bgcblack"); potluckend0(); potluckend1(); print"\n";

	potluckend1(); potluckmulti1end0(); potluckmid0(); potluckreel4(); sep; potluckslot1(); sep; potluckmid0(); potluckreel5(); sep; potluckslot1(); sep; potluckmid0(); potluckreel6(); sep; potluckslot1(); sep; potluckmid0(); potluckslota(); print"\n";
	potluckend1(); potluckmulti2end0(); potluckmid0(); potluckreel4(); sep; potluckslot2(); sep; potluckmid0(); potluckreel5(); sep; potluckslot2(); sep; potluckmid0(); potluckreel6(); sep; potluckslot2(); sep; potluckmid0(); potluckslotb(); beepalrm();
	potluckend1(); potluckmulti3end0(); potluckmid0(); potluckreel4(); sep; potluckslot3(); sep; potluckmid0(); potluckreel5(); sep; potluckslot3(); sep; potluckmid0(); potluckreel6(); sep; potluckslot3(); sep; potluckmid0(); potluckslotb(); beepalrm();
	potluckend1(); potluckmid1(); potluckmid1(); potluckend0(); potluckendp2(); potluckmid0(); potluckreel4(); sep; potluckslot4(); sep; potluckmid0(); potluckreel5(); sep; potluckslot4(); sep; potluckmid0(); potluckreel6(); sep; potluckslot4(); sep; potluckmid0(); potluckslotb(); beepalrm();
	potluckend1(); potluckmulti1wldend0(); potluckmid0(); potluckreel4(); sep; potluckslot5(); sep; potluckmid0(); potluckreel5(); sep; potluckslot5(); sep; potluckmid0(); potluckreel6(); sep; potluckslot5(); sep; potluckmid0(); potluckslotb(); beepalrm();
	potluckend1(); potluckmulti2wldend0(); potluckmid0(); potluckreel4(); sep; potluckslot6(); sep; potluckmid0(); potluckreel5(); sep; potluckslot6(); sep; potluckmid0(); potluckreel6(); sep; potluckslot6(); sep; potluckmid0(); potluckslota(); beepalrm();
	print colored('|-------------------',"$boldblack on_$bgcblack"); print colored('--================--================--================--',"$boldblack on_$bgcblack"); print colored('---|',"$boldblack on_$bgcblack"); beepalrm();
	potluckend1(); print colored('    GPC-SLOTS 2                        ',"$boldyellow on_$bgcyellow"); potluckwinnings(); potluckfunds(); potluckend1(); beepalrm();
	print colored('\------------------------------------------------------------------------------/',"$boldblack on_$bgcblack");  beepalrm();	
	
	$beepnum = 0;
}

sub potluckwinnings {
	print colored(' WINNINGS ',"$boldyellow on_$bgcyellow");
	sep;
	if ($potluckapotluckmoney > 9999999999) {
	print colored(sprintf("%.4e", $potluckapotluckmoney),"$boldcyan on_$bgccyan");
	} elsif ($potluckapotluckmoney >= 1000000000) {
	print colored("$potluckapotluckmoney","$boldcyan on_$bgccyan");
	} elsif ($potluckapotluckmoney >= 100000000) {
	print colored(" $potluckapotluckmoney","$boldcyan on_$bgccyan");
	} elsif ($potluckapotluckmoney >= 10000000) {
	print colored("  $potluckapotluckmoney","$boldcyan on_$bgccyan");
	} elsif ($potluckapotluckmoney >= 1000000) {
	print colored("   $potluckapotluckmoney","$boldcyan on_$bgccyan");
	} elsif ($potluckapotluckmoney >= 100000) {
	print colored("    $potluckapotluckmoney","$boldcyan on_$bgccyan");
	} elsif ($potluckapotluckmoney >= 10000) {
	print colored("     $potluckapotluckmoney","$boldcyan on_$bgccyan");
	} elsif ($potluckapotluckmoney >= 1000) {
	print colored("      $potluckapotluckmoney","$boldcyan on_$bgccyan");
	} elsif ($potluckapotluckmoney >= 100) {
	print colored("       $potluckapotluckmoney","$boldcyan on_$bgccyan");
	} elsif ($potluckapotluckmoney >= 10) {
	print colored("        $potluckapotluckmoney","$boldcyan on_$bgccyan");
	} elsif ($potluckapotluckmoney >= 1) {
	print colored("         $potluckapotluckmoney","$boldcyan on_$bgccyan");
	} else {
	print colored("         $potluckapotluckmoney","$boldcyan on_$bgccyan");
	}
	sep;
}

sub potluckfunds {
	print colored('   FUNDS ',"$boldyellow on_$bgcyellow");
	sep;
	if ($money > 9999999999) {
	print colored(sprintf("%.4e", $money),"$boldcyan on_$bgccyan");
	} elsif ($money >= 1000000000) {
	print colored("$money","$boldcyan on_$bgccyan");
	} elsif ($money >= 100000000) {
	print colored(" $money","$boldcyan on_$bgccyan");
	} elsif ($money >= 10000000) {
	print colored("  $money","$boldcyan on_$bgccyan");
	} elsif ($money >= 1000000) {
	print colored("   $money","$boldcyan on_$bgccyan");
	} elsif ($money >= 100000) {
	print colored("    $money","$boldcyan on_$bgccyan");
	} elsif ($money >= 10000) {
	print colored("     $money","$boldcyan on_$bgccyan");
	} elsif ($money >= 1000) {
	print colored("      $money","$boldcyan on_$bgccyan");
	} elsif ($money >= 100) {
	print colored("       $money","$boldcyan on_$bgccyan");
	} elsif ($money >= 10) {
	print colored("        $money","$boldcyan on_$bgccyan");
	} elsif ($money >= 1) {
	print colored("         $money","$boldcyan on_$bgccyan");
	} else {
	print colored("         $money","$boldcyan on_$bgccyan");
	}
	sep;
}



################################################################################################################################
## GENRE: Roulette
## NAME: Russian Roulette: 25 or Life
## AUTHOR: MikeeUSA

sub ruskieinit {
	$ruskierand = int(rand(6));
	$ruskie2rand = 42;
}

sub ruskietop {
	if ($ruskieold == 1) {
	print colored('/--------------',"$boldblack on_$bgcblack");
	print colored('--------------------------------------------------',"$boldmagenta on_$bgcmagenta"); 
	print colored('--------------\\',"$boldblack on_$bgcblack");
	print"\n";

	print colored('|   P = PLAY   ',"$boldblack on_$bgcblack");
	print colored('                  GPC-SLOTS 2                     ',"$black on_$bgcmagenta");
	print colored('  C = RETURN  |',"$boldblack on_$bgcblack"); print"\n";

	print colored('| EXIT = QUIT  ',"$boldblack on_$bgcblack");
	print colored('   /--------------------------------\\             ',"$boldmagenta on_$bgcmagenta");
	print colored('TO CASINO MENU|',"$boldblack on_$bgcblack"); print"\n";
	} else {
	print colored('/--------------',"$boldblack on_$bgcblack");
	print colored('--------------------------------------------------',"$boldred on_$bgcred"); 
	print colored('--------------\\',"$boldblack on_$bgcblack");
	print"\n";

	print colored('|   P = PLAY   ',"$boldblack on_$bgcblack");
	print colored('                  GPC-SLOTS 2                     ',"$black on_$bgcred");
	print colored('  C = RETURN  |',"$boldblack on_$bgcblack"); print"\n";

	print colored('| EXIT = QUIT  ',"$boldblack on_$bgcblack");
	print colored('   /--------------------------------\\             ',"$boldred on_$bgcred");
	print colored('TO CASINO MENU|',"$boldblack on_$bgcblack"); print"\n";
	}
}

sub ruskie0rlv {
	if ($ruskieold == 1) {
	print colored('|                 |',"$boldmagenta on_$bgcmagenta"); print colored('--------------------------------',"$boldblack on_$bgcblack");print colored('|                           |',"$boldmagenta on_$bgcmagenta"); print"\n";
	print colored('|     2222222     |',"$boldmagenta on_$bgcmagenta"); print colored('---------------',"$boldblack on_$bgcblack"); print colored('/\\',"$boldblack on_$bgcwhite"); print colored('---------------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldmagenta on_$bgcmagenta");  print"\n";
	print colored('|  2222222222222  |',"$boldmagenta on_$bgcmagenta"); print colored('------------',"$boldblack on_$bgcblack"); print colored('/ ____ \\',"$boldblack on_$bgcwhite"); print colored('------------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldmagenta on_$bgcmagenta");  print"\n";
	print colored('| 222         222 |',"$boldmagenta on_$bgcmagenta"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('/ /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\ \\',"$boldblack on_$bgcwhite"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('|      25  or Your Life     |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|             222 |',"$boldmagenta on_$bgcmagenta"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('| ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored(' >< ',"$yellow on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored(' |',"$boldblack on_$bgcwhite"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|           2222  |',"$boldmagenta on_$bgcmagenta"); print colored('----------',"$boldblack on_$bgcblack"); print colored('/\\ \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ /\\',"$boldblack on_$bgcwhite"); print colored('----------',"$boldblack on_$bgcblack");print colored('|                           |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|         2222    |',"$boldmagenta on_$bgcmagenta"); print colored('---',"$boldblack on_$bgcblack"); print colored('/ ____   \\______/   ____ \\',"$boldblack on_$bgcwhite"); print colored('---',"$boldblack on_$bgcblack");print colored('|',"$boldmagenta on_$bgcmagenta");print colored('  Win: 25 COINS            ',"$boldyellow on_$bgcmagenta");print colored('|',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|       2222      |',"$boldmagenta on_$bgcmagenta"); print colored('--',"$boldblack on_$bgcblack"); print colored('| /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\    ||||    /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\ |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|',"$boldmagenta on_$bgcmagenta");print colored(' Lose: YOUR LIFE           ',"$boldyellow on_$bgcmagenta");print colored('|',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|     2222        |',"$boldmagenta on_$bgcmagenta"); print colored('--',"$boldblack on_$bgcblack"); print colored('| ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ||||    ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored(' |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|                           |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|   2222          |',"$boldmagenta on_$bgcmagenta"); print colored('--',"$boldblack on_$bgcblack"); print colored('| \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/    ||||    \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|                           |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('| 222222222222222 |',"$boldmagenta on_$bgcmagenta"); print colored('---',"$boldblack on_$bgcblack"); print colored('\\          ||||          /',"$boldblack on_$bgcwhite"); print colored('---',"$boldblack on_$bgcblack");print colored('|                           |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|                 |',"$boldmagenta on_$bgcmagenta"); print colored('----',"$boldblack on_$bgcblack"); print colored('>         ||||         <',"$boldblack on_$bgcwhite"); print colored('----',"$boldblack on_$bgcblack");print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored(' _____________  ',"$boldblack on_$bgcmagenta"); print colored('     |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('| 555555555555555 |',"$boldmagenta on_$bgcmagenta"); print colored('---',"$boldblack on_$bgcblack"); print colored('/ ____     \__/     ____ \\',"$boldblack on_$bgcwhite");print colored('---',"$boldblack on_$bgcblack"); print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored('|',"$boldblack on_$bgcmagenta"); print colored('|~~~~~~~~~~~|',"$boldred on_$bgcred");print colored('|',"$boldblack on_$bgcmagenta"); print colored('      |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('| 555555555555555 |',"$boldmagenta on_$bgcmagenta"); print colored('--',"$boldblack on_$bgcblack"); print colored('| /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\            /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\ |',"$boldblack on_$bgcwhite"); ;print colored('--',"$boldblack on_$bgcblack");print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored('|',"$boldblack on_$bgcmagenta"); print colored('|           |',"$boldred on_$bgcred");print colored('|',"$boldblack on_$bgcmagenta"); print colored('      |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('| 5555            |',"$boldmagenta on_$bgcmagenta"); print colored('--',"$boldblack on_$bgcblack"); print colored('| ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored('            ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored(' |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored('|',"$boldblack on_$bgcmagenta"); print colored('|   PRESS   |',"$boldred on_$bgcred");print colored('|',"$boldblack on_$bgcmagenta"); print colored('      |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('| 5555            |',"$boldmagenta on_$bgcmagenta"); print colored('--',"$boldblack on_$bgcblack"); print colored('| \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/    ____    \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ |',"$boldblack on_$bgcwhite");print colored('--',"$boldblack on_$bgcblack");print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored('|',"$boldblack on_$bgcmagenta"); print colored('|           |',"$boldred on_$bgcred");print colored('|',"$boldblack on_$bgcmagenta"); print colored('      |',"$boldmagenta on_$bgcmagenta");  print"\n";
	print colored('|  5555           |',"$boldmagenta on_$bgcmagenta"); print colored('---',"$boldblack on_$bgcblack"); print colored('\\______   /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\   ______/',"$boldblack on_$bgcwhite");print colored('---',"$boldblack on_$bgcblack");  print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored('|',"$boldblack on_$bgcmagenta"); print colored('|           |',"$boldred on_$bgcred");print colored('|',"$boldblack on_$bgcmagenta"); print colored('      |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|    55555555     |',"$boldmagenta on_$bgcmagenta"); print colored('----------',"$boldblack on_$bgcblack"); print colored('\\  ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored('  /',"$boldblack on_$bgcwhite"); print colored('----------',"$boldblack on_$bgcblack");print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored('|',"$boldblack on_$bgcmagenta"); print colored('|___________|',"$boldred on_$bgcred");print colored('|',"$boldblack on_$bgcmagenta"); print colored('      |',"$boldmagenta on_$bgcmagenta"); print"\n";
	print colored('|      555555555  |',"$boldmagenta on_$bgcmagenta"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('\\ \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ /',"$boldblack on_$bgcwhite");print colored('-----------',"$boldblack on_$bgcblack");print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored(' ~~~~~~~~~~~~~  ',"$boldblack on_$bgcmagenta"); print colored('     |',"$boldmagenta on_$bgcmagenta");    print"\n";
	print colored('|            5555 |',"$boldmagenta on_$bgcmagenta"); print colored('------------',"$boldblack on_$bgcblack"); print colored('\\______/',"$boldblack on_$bgcwhite"); print colored('------------',"$boldblack on_$bgcblack");  print colored('|                           |',"$boldmagenta on_$bgcmagenta"); print"\n"; 
	print colored('|            5555 |',"$boldmagenta on_$bgcmagenta"); print colored('--------------------------------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldmagenta on_$bgcmagenta");print"\n";
	} else {
	ruskieleft1();  print colored('--------------------------------',"$boldblack on_$bgcblack");print colored('|                           |',"$boldred on_$bgcred"); print"\n";
	ruskieleft2();  print colored('---------------',"$boldblack on_$bgcblack"); print colored('/\\',"$boldblack on_$bgcwhite"); print colored('---------------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldred on_$bgcred");  print"\n";
	ruskieleft3();  print colored('------------',"$boldblack on_$bgcblack"); print colored('/ ____ \\',"$boldblack on_$bgcwhite"); print colored('------------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldred on_$bgcred");  print"\n";
	ruskieleft4();  print colored('-----------',"$boldblack on_$bgcblack"); print colored('/ /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\ \\',"$boldblack on_$bgcwhite"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('|      25  or Your Life     |',"$boldred on_$bgcred");print"\n";
	ruskieleft5();  print colored('-----------',"$boldblack on_$bgcblack"); print colored('| ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored(' >< ',"$yellow on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored(' |',"$boldblack on_$bgcwhite"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldred on_$bgcred");print"\n";
	ruskieleft6();  print colored('----------',"$boldblack on_$bgcblack"); print colored('/\\ \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ /\\',"$boldblack on_$bgcwhite"); print colored('----------',"$boldblack on_$bgcblack");print colored('|                           |',"$boldred on_$bgcred");print"\n";
	ruskieleft7();  print colored('---',"$boldblack on_$bgcblack"); print colored('/ ____   \\______/   ____ \\',"$boldblack on_$bgcwhite"); print colored('---',"$boldblack on_$bgcblack");print colored('|',"$boldred on_$bgcred");print colored('  Win: 25 COINS            ',"$boldyellow on_$bgcred");print colored('|',"$boldred on_$bgcred");print"\n";
	ruskieleft8();  print colored('--',"$boldblack on_$bgcblack"); print colored('| /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\    ||||    /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\ |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|',"$boldred on_$bgcred");print colored(' Lose: YOUR LIFE           ',"$boldyellow on_$bgcred");print colored('|',"$boldred on_$bgcred");print"\n";
	ruskieleft9();  print colored('--',"$boldblack on_$bgcblack"); print colored('| ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ||||    ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored(' |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|                           |',"$boldred on_$bgcred");print"\n";
	ruskieleft10(); print colored('--',"$boldblack on_$bgcblack"); print colored('| \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/    ||||    \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|                           |',"$boldred on_$bgcred");print"\n";
	ruskieleft11(); print colored('---',"$boldblack on_$bgcblack"); print colored('\\          ||||          /',"$boldblack on_$bgcwhite"); print colored('---',"$boldblack on_$bgcblack");print colored('|                           |',"$boldred on_$bgcred");print"\n";
	ruskieleft12(); print colored('----',"$boldblack on_$bgcblack"); print colored('>         ||||         <',"$boldblack on_$bgcwhite"); print colored('----',"$boldblack on_$bgcblack");print colored('|      ',"$boldred on_$bgcred"); ruskiebutton1(); print colored('      |',"$boldred on_$bgcred");print"\n";
	ruskieleft13(); print colored('---',"$boldblack on_$bgcblack"); print colored('/ ____     \__/     ____ \\',"$boldblack on_$bgcwhite");print colored('---',"$boldblack on_$bgcblack"); print colored('|      ',"$boldred on_$bgcred"); ruskiebutton2(); print colored('      |',"$boldred on_$bgcred");print"\n";
	ruskieleft14(); print colored('--',"$boldblack on_$bgcblack"); print colored('| /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\            /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\ |',"$boldblack on_$bgcwhite"); ;print colored('--',"$boldblack on_$bgcblack");print colored('|      ',"$boldred on_$bgcred"); ruskiebutton6(); print colored('      |',"$boldred on_$bgcred");print"\n";
	ruskieleft15(); print colored('--',"$boldblack on_$bgcblack"); print colored('| ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored('            ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored(' |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|      ',"$boldred on_$bgcred"); ruskiebutton4(); print colored('      |',"$boldred on_$bgcred");print"\n";
	ruskieleft16(); print colored('--',"$boldblack on_$bgcblack"); print colored('| \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/    ____    \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ |',"$boldblack on_$bgcwhite");print colored('--',"$boldblack on_$bgcblack");print colored('|      ',"$boldred on_$bgcred"); ruskiebutton6(); print colored('      |',"$boldred on_$bgcred");  print"\n";
	ruskieleft17(); print colored('---',"$boldblack on_$bgcblack"); print colored('\\______   /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\   ______/',"$boldblack on_$bgcwhite");print colored('---',"$boldblack on_$bgcblack");  print colored('|      ',"$boldred on_$bgcred"); ruskiebutton6(); print colored('      |',"$boldred on_$bgcred");print"\n";
	ruskieleft18(); print colored('----------',"$boldblack on_$bgcblack"); print colored('\\  ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored('  /',"$boldblack on_$bgcwhite"); print colored('----------',"$boldblack on_$bgcblack");print colored('|      ',"$boldred on_$bgcred"); ruskiebutton7(); print colored('      |',"$boldred on_$bgcred"); print"\n";
	ruskieleft19(); print colored('-----------',"$boldblack on_$bgcblack"); print colored('\\ \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ /',"$boldblack on_$bgcwhite");print colored('-----------',"$boldblack on_$bgcblack");print colored('|      ',"$boldred on_$bgcred"); ruskiebutton8(); print colored('      |',"$boldred on_$bgcred");    print"\n";
	ruskieleft20(); print colored('------------',"$boldblack on_$bgcblack"); print colored('\\______/',"$boldblack on_$bgcwhite"); print colored('------------',"$boldblack on_$bgcblack");  print colored('|                           |',"$boldred on_$bgcred"); print"\n"; 
	ruskieleft21(); print colored('--------------------------------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldred on_$bgcred");print"\n";
	}
}

sub ruskie1rlv {
	if ($ruskieold == 1) {
	print colored('|                 |',"$boldmagenta on_$bgcmagenta"); print colored('--------------------------------',"$boldblack on_$bgcblack");print colored('|                           |',"$boldmagenta on_$bgcmagenta"); print"\n";
	print colored('|     2222222     |',"$boldmagenta on_$bgcmagenta"); print colored('---------------',"$boldblack on_$bgcblack"); print colored('/\\',"$boldblack on_$bgcwhite"); print colored('---------------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldmagenta on_$bgcmagenta");  print"\n";
	print colored('|  2222222222222  |',"$boldmagenta on_$bgcmagenta"); print colored('------------',"$boldblack on_$bgcblack"); print colored('/ ____ \\',"$boldblack on_$bgcwhite"); print colored('------------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldmagenta on_$bgcmagenta");  print"\n";
	print colored('| 222         222 |',"$boldmagenta on_$bgcmagenta"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('/ /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\ \\',"$boldblack on_$bgcwhite"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('|      25  or Your Life     |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|             222 |',"$boldmagenta on_$bgcmagenta"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('| ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored(' |',"$boldblack on_$bgcwhite"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|           2222  |',"$boldmagenta on_$bgcmagenta"); print colored('----------',"$boldblack on_$bgcblack"); print colored('/\\ \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ /\\',"$boldblack on_$bgcwhite"); print colored('----------',"$boldblack on_$bgcblack");print colored('|                           |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|         2222    |',"$boldmagenta on_$bgcmagenta"); print colored('---',"$boldblack on_$bgcblack"); print colored('/ ____   \\______/   ____ \\',"$boldblack on_$bgcwhite"); print colored('---',"$boldblack on_$bgcblack");print colored('|',"$boldmagenta on_$bgcmagenta");print colored('  Win: 25 COINS            ',"$boldyellow on_$bgcmagenta");print colored('|',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|       2222      |',"$boldmagenta on_$bgcmagenta"); print colored('--',"$boldblack on_$bgcblack"); print colored('| /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\    ||||    /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\ |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|',"$boldmagenta on_$bgcmagenta");print colored(' Lose: YOUR LIFE           ',"$boldyellow on_$bgcmagenta");print colored('|',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|     2222        |',"$boldmagenta on_$bgcmagenta"); print colored('--',"$boldblack on_$bgcblack"); print colored('| ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored(' >< ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ||||    ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored(' |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|                           |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|   2222          |',"$boldmagenta on_$bgcmagenta"); print colored('--',"$boldblack on_$bgcblack"); print colored('| \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/    ||||    \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|                           |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('| 222222222222222 |',"$boldmagenta on_$bgcmagenta"); print colored('---',"$boldblack on_$bgcblack"); print colored('\\          ||||          /',"$boldblack on_$bgcwhite"); print colored('---',"$boldblack on_$bgcblack");print colored('|                           |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|                 |',"$boldmagenta on_$bgcmagenta"); print colored('----',"$boldblack on_$bgcblack"); print colored('>         ||||         <',"$boldblack on_$bgcwhite"); print colored('----',"$boldblack on_$bgcblack");print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored(' _____________  ',"$boldblack on_$bgcmagenta"); print colored('     |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('| 555555555555555 |',"$boldmagenta on_$bgcmagenta"); print colored('---',"$boldblack on_$bgcblack"); print colored('/ ____     \__/     ____ \\',"$boldblack on_$bgcwhite");print colored('---',"$boldblack on_$bgcblack"); print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored('|',"$boldblack on_$bgcmagenta"); print colored('|~~~~~~~~~~~|',"$boldred on_$bgcred");print colored('|',"$boldblack on_$bgcmagenta"); print colored('      |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('| 555555555555555 |',"$boldmagenta on_$bgcmagenta"); print colored('--',"$boldblack on_$bgcblack"); print colored('| /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\            /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\ |',"$boldblack on_$bgcwhite"); ;print colored('--',"$boldblack on_$bgcblack");print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored('|',"$boldblack on_$bgcmagenta"); print colored('|           |',"$boldred on_$bgcred");print colored('|',"$boldblack on_$bgcmagenta"); print colored('      |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('| 5555            |',"$boldmagenta on_$bgcmagenta"); print colored('--',"$boldblack on_$bgcblack"); print colored('| ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored('            ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored(' |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored('|',"$boldblack on_$bgcmagenta"); print colored('|   PRESS   |',"$boldred on_$bgcred");print colored('|',"$boldblack on_$bgcmagenta"); print colored('      |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('| 5555            |',"$boldmagenta on_$bgcmagenta"); print colored('--',"$boldblack on_$bgcblack"); print colored('| \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/    ____    \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ |',"$boldblack on_$bgcwhite");print colored('--',"$boldblack on_$bgcblack");print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored('|',"$boldblack on_$bgcmagenta"); print colored('|           |',"$boldred on_$bgcred");print colored('|',"$boldblack on_$bgcmagenta"); print colored('      |',"$boldmagenta on_$bgcmagenta");  print"\n";
	print colored('|  5555           |',"$boldmagenta on_$bgcmagenta"); print colored('---',"$boldblack on_$bgcblack"); print colored('\\______   /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\   ______/',"$boldblack on_$bgcwhite");print colored('---',"$boldblack on_$bgcblack");  print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored('|',"$boldblack on_$bgcmagenta"); print colored('|           |',"$boldred on_$bgcred");print colored('|',"$boldblack on_$bgcmagenta"); print colored('      |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|    55555555     |',"$boldmagenta on_$bgcmagenta"); print colored('----------',"$boldblack on_$bgcblack"); print colored('\\  ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored('  /',"$boldblack on_$bgcwhite"); print colored('----------',"$boldblack on_$bgcblack");print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored('|',"$boldblack on_$bgcmagenta"); print colored('|___________|',"$boldred on_$bgcred");print colored('|',"$boldblack on_$bgcmagenta"); print colored('      |',"$boldmagenta on_$bgcmagenta"); print"\n";
	print colored('|      555555555  |',"$boldmagenta on_$bgcmagenta"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('\\ \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ /',"$boldblack on_$bgcwhite");print colored('-----------',"$boldblack on_$bgcblack");print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored(' ~~~~~~~~~~~~~  ',"$boldblack on_$bgcmagenta"); print colored('     |',"$boldmagenta on_$bgcmagenta");    print"\n";
	print colored('|            5555 |',"$boldmagenta on_$bgcmagenta"); print colored('------------',"$boldblack on_$bgcblack"); print colored('\\______/',"$boldblack on_$bgcwhite"); print colored('------------',"$boldblack on_$bgcblack");  print colored('|                           |',"$boldmagenta on_$bgcmagenta"); print"\n"; 
	print colored('|            5555 |',"$boldmagenta on_$bgcmagenta"); print colored('--------------------------------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldmagenta on_$bgcmagenta");print"\n";
	} else {
	ruskieleft1();  print colored('--------------------------------',"$boldblack on_$bgcblack");print colored('|                           |',"$boldred on_$bgcred"); print"\n";
	ruskieleft2();  print colored('---------------',"$boldblack on_$bgcblack"); print colored('/\\',"$boldblack on_$bgcwhite"); print colored('---------------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldred on_$bgcred");  print"\n";
	ruskieleft3();  print colored('------------',"$boldblack on_$bgcblack"); print colored('/ ____ \\',"$boldblack on_$bgcwhite"); print colored('------------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldred on_$bgcred");  print"\n";
	ruskieleft4();  print colored('-----------',"$boldblack on_$bgcblack"); print colored('/ /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\ \\',"$boldblack on_$bgcwhite"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('|      25  or Your Life     |',"$boldred on_$bgcred");print"\n";
	ruskieleft5();  print colored('-----------',"$boldblack on_$bgcblack"); print colored('| ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored(' |',"$boldblack on_$bgcwhite"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldred on_$bgcred");print"\n";
	ruskieleft6();  print colored('----------',"$boldblack on_$bgcblack"); print colored('/\\ \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ /\\',"$boldblack on_$bgcwhite"); print colored('----------',"$boldblack on_$bgcblack");print colored('|                           |',"$boldred on_$bgcred");print"\n";
	ruskieleft7();  print colored('---',"$boldblack on_$bgcblack"); print colored('/ ____   \\______/   ____ \\',"$boldblack on_$bgcwhite"); print colored('---',"$boldblack on_$bgcblack");print colored('|',"$boldred on_$bgcred");print colored('  Win: 25 COINS            ',"$boldyellow on_$bgcred");print colored('|',"$boldred on_$bgcred");print"\n";
	ruskieleft8();  print colored('--',"$boldblack on_$bgcblack"); print colored('| /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\    ||||    /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\ |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|',"$boldred on_$bgcred");print colored(' Lose: YOUR LIFE           ',"$boldyellow on_$bgcred");print colored('|',"$boldred on_$bgcred");print"\n";
	ruskieleft9();  print colored('--',"$boldblack on_$bgcblack"); print colored('| ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored(' >< ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ||||    ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored(' |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|                           |',"$boldred on_$bgcred");print"\n";
	ruskieleft10(); print colored('--',"$boldblack on_$bgcblack"); print colored('| \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/    ||||    \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|                           |',"$boldred on_$bgcred");print"\n";
	ruskieleft11(); print colored('---',"$boldblack on_$bgcblack"); print colored('\\          ||||          /',"$boldblack on_$bgcwhite"); print colored('---',"$boldblack on_$bgcblack");print colored('|                           |',"$boldred on_$bgcred");print"\n";
	ruskieleft12(); print colored('----',"$boldblack on_$bgcblack"); print colored('>         ||||         <',"$boldblack on_$bgcwhite"); print colored('----',"$boldblack on_$bgcblack");print colored('|      ',"$boldred on_$bgcred"); ruskiebutton1(); print colored('      |',"$boldred on_$bgcred");print"\n";
	ruskieleft13(); print colored('---',"$boldblack on_$bgcblack"); print colored('/ ____     \__/     ____ \\',"$boldblack on_$bgcwhite");print colored('---',"$boldblack on_$bgcblack"); print colored('|      ',"$boldred on_$bgcred"); ruskiebutton2(); print colored('      |',"$boldred on_$bgcred");print"\n";
	ruskieleft14(); print colored('--',"$boldblack on_$bgcblack"); print colored('| /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\            /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\ |',"$boldblack on_$bgcwhite"); ;print colored('--',"$boldblack on_$bgcblack");print colored('|      ',"$boldred on_$bgcred"); ruskiebutton6(); print colored('      |',"$boldred on_$bgcred");print"\n";
	ruskieleft15(); print colored('--',"$boldblack on_$bgcblack"); print colored('| ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored('            ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored(' |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|      ',"$boldred on_$bgcred"); ruskiebutton4(); print colored('      |',"$boldred on_$bgcred");print"\n";
	ruskieleft16(); print colored('--',"$boldblack on_$bgcblack"); print colored('| \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/    ____    \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ |',"$boldblack on_$bgcwhite");print colored('--',"$boldblack on_$bgcblack");print colored('|      ',"$boldred on_$bgcred"); ruskiebutton6(); print colored('      |',"$boldred on_$bgcred");  print"\n";
	ruskieleft17(); print colored('---',"$boldblack on_$bgcblack"); print colored('\\______   /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\   ______/',"$boldblack on_$bgcwhite");print colored('---',"$boldblack on_$bgcblack");  print colored('|      ',"$boldred on_$bgcred"); ruskiebutton6(); print colored('      |',"$boldred on_$bgcred");print"\n";
	ruskieleft18(); print colored('----------',"$boldblack on_$bgcblack"); print colored('\\  ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored('  /',"$boldblack on_$bgcwhite"); print colored('----------',"$boldblack on_$bgcblack");print colored('|      ',"$boldred on_$bgcred"); ruskiebutton7(); print colored('      |',"$boldred on_$bgcred"); print"\n";
	ruskieleft19(); print colored('-----------',"$boldblack on_$bgcblack"); print colored('\\ \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ /',"$boldblack on_$bgcwhite");print colored('-----------',"$boldblack on_$bgcblack");print colored('|      ',"$boldred on_$bgcred"); ruskiebutton8(); print colored('      |',"$boldred on_$bgcred");    print"\n";
	ruskieleft20(); print colored('------------',"$boldblack on_$bgcblack"); print colored('\\______/',"$boldblack on_$bgcwhite"); print colored('------------',"$boldblack on_$bgcblack");  print colored('|                           |',"$boldred on_$bgcred"); print"\n"; 
	ruskieleft21(); print colored('--------------------------------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldred on_$bgcred");print"\n";
	}
}

sub ruskie2rlv {
	if ($ruskieold == 1) {
	print colored('|                 |',"$boldmagenta on_$bgcmagenta"); print colored('--------------------------------',"$boldblack on_$bgcblack");print colored('|                           |',"$boldmagenta on_$bgcmagenta"); print"\n";
	print colored('|     2222222     |',"$boldmagenta on_$bgcmagenta"); print colored('---------------',"$boldblack on_$bgcblack"); print colored('/\\',"$boldblack on_$bgcwhite"); print colored('---------------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldmagenta on_$bgcmagenta");  print"\n";
	print colored('|  2222222222222  |',"$boldmagenta on_$bgcmagenta"); print colored('------------',"$boldblack on_$bgcblack"); print colored('/ ____ \\',"$boldblack on_$bgcwhite"); print colored('------------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldmagenta on_$bgcmagenta");  print"\n";
	print colored('| 222         222 |',"$boldmagenta on_$bgcmagenta"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('/ /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\ \\',"$boldblack on_$bgcwhite"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('|      25  or Your Life     |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|             222 |',"$boldmagenta on_$bgcmagenta"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('| ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored(' |',"$boldblack on_$bgcwhite"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|           2222  |',"$boldmagenta on_$bgcmagenta"); print colored('----------',"$boldblack on_$bgcblack"); print colored('/\\ \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ /\\',"$boldblack on_$bgcwhite"); print colored('----------',"$boldblack on_$bgcblack");print colored('|                           |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|         2222    |',"$boldmagenta on_$bgcmagenta"); print colored('---',"$boldblack on_$bgcblack"); print colored('/ ____   \\______/   ____ \\',"$boldblack on_$bgcwhite"); print colored('---',"$boldblack on_$bgcblack");print colored('|',"$boldmagenta on_$bgcmagenta");print colored('  Win: 25 COINS            ',"$boldyellow on_$bgcmagenta");print colored('|',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|       2222      |',"$boldmagenta on_$bgcmagenta"); print colored('--',"$boldblack on_$bgcblack"); print colored('| /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\    ||||    /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\ |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|',"$boldmagenta on_$bgcmagenta");print colored(' Lose: YOUR LIFE           ',"$boldyellow on_$bgcmagenta");print colored('|',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|     2222        |',"$boldmagenta on_$bgcmagenta"); print colored('--',"$boldblack on_$bgcblack"); print colored('| ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ||||    ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored(' |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|                           |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|   2222          |',"$boldmagenta on_$bgcmagenta"); print colored('--',"$boldblack on_$bgcblack"); print colored('| \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/    ||||    \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|                           |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('| 222222222222222 |',"$boldmagenta on_$bgcmagenta"); print colored('---',"$boldblack on_$bgcblack"); print colored('\\          ||||          /',"$boldblack on_$bgcwhite"); print colored('---',"$boldblack on_$bgcblack");print colored('|                           |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|                 |',"$boldmagenta on_$bgcmagenta"); print colored('----',"$boldblack on_$bgcblack"); print colored('>         ||||         <',"$boldblack on_$bgcwhite"); print colored('----',"$boldblack on_$bgcblack");print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored(' _____________  ',"$boldblack on_$bgcmagenta"); print colored('     |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('| 555555555555555 |',"$boldmagenta on_$bgcmagenta"); print colored('---',"$boldblack on_$bgcblack"); print colored('/ ____     \__/     ____ \\',"$boldblack on_$bgcwhite");print colored('---',"$boldblack on_$bgcblack"); print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored('|',"$boldblack on_$bgcmagenta"); print colored('|~~~~~~~~~~~|',"$boldred on_$bgcred");print colored('|',"$boldblack on_$bgcmagenta"); print colored('      |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('| 555555555555555 |',"$boldmagenta on_$bgcmagenta"); print colored('--',"$boldblack on_$bgcblack"); print colored('| /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\            /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\ |',"$boldblack on_$bgcwhite"); ;print colored('--',"$boldblack on_$bgcblack");print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored('|',"$boldblack on_$bgcmagenta"); print colored('|           |',"$boldred on_$bgcred");print colored('|',"$boldblack on_$bgcmagenta"); print colored('      |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('| 5555            |',"$boldmagenta on_$bgcmagenta"); print colored('--',"$boldblack on_$bgcblack"); print colored('| ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored(' >< ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored('            ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored(' |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored('|',"$boldblack on_$bgcmagenta"); print colored('|   PRESS   |',"$boldred on_$bgcred");print colored('|',"$boldblack on_$bgcmagenta"); print colored('      |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('| 5555            |',"$boldmagenta on_$bgcmagenta"); print colored('--',"$boldblack on_$bgcblack"); print colored('| \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/    ____    \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ |',"$boldblack on_$bgcwhite");print colored('--',"$boldblack on_$bgcblack");print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored('|',"$boldblack on_$bgcmagenta"); print colored('|           |',"$boldred on_$bgcred");print colored('|',"$boldblack on_$bgcmagenta"); print colored('      |',"$boldmagenta on_$bgcmagenta");  print"\n";
	print colored('|  5555           |',"$boldmagenta on_$bgcmagenta"); print colored('---',"$boldblack on_$bgcblack"); print colored('\\______   /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\   ______/',"$boldblack on_$bgcwhite");print colored('---',"$boldblack on_$bgcblack");  print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored('|',"$boldblack on_$bgcmagenta"); print colored('|           |',"$boldred on_$bgcred");print colored('|',"$boldblack on_$bgcmagenta"); print colored('      |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|    55555555     |',"$boldmagenta on_$bgcmagenta"); print colored('----------',"$boldblack on_$bgcblack"); print colored('\\  ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored('  /',"$boldblack on_$bgcwhite"); print colored('----------',"$boldblack on_$bgcblack");print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored('|',"$boldblack on_$bgcmagenta"); print colored('|___________|',"$boldred on_$bgcred");print colored('|',"$boldblack on_$bgcmagenta"); print colored('      |',"$boldmagenta on_$bgcmagenta"); print"\n";
	print colored('|      555555555  |',"$boldmagenta on_$bgcmagenta"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('\\ \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ /',"$boldblack on_$bgcwhite");print colored('-----------',"$boldblack on_$bgcblack");print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored(' ~~~~~~~~~~~~~  ',"$boldblack on_$bgcmagenta"); print colored('     |',"$boldmagenta on_$bgcmagenta");    print"\n";
	print colored('|            5555 |',"$boldmagenta on_$bgcmagenta"); print colored('------------',"$boldblack on_$bgcblack"); print colored('\\______/',"$boldblack on_$bgcwhite"); print colored('------------',"$boldblack on_$bgcblack");  print colored('|                           |',"$boldmagenta on_$bgcmagenta"); print"\n"; 
	print colored('|            5555 |',"$boldmagenta on_$bgcmagenta"); print colored('--------------------------------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldmagenta on_$bgcmagenta");print"\n";
	} else {
	ruskieleft1();  print colored('--------------------------------',"$boldblack on_$bgcblack");print colored('|                           |',"$boldred on_$bgcred"); print"\n";
	ruskieleft2();  print colored('---------------',"$boldblack on_$bgcblack"); print colored('/\\',"$boldblack on_$bgcwhite"); print colored('---------------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldred on_$bgcred");  print"\n";
	ruskieleft3();  print colored('------------',"$boldblack on_$bgcblack"); print colored('/ ____ \\',"$boldblack on_$bgcwhite"); print colored('------------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldred on_$bgcred");  print"\n";
	ruskieleft4();  print colored('-----------',"$boldblack on_$bgcblack"); print colored('/ /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\ \\',"$boldblack on_$bgcwhite"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('|      25  or Your Life     |',"$boldred on_$bgcred");print"\n";
	ruskieleft5();  print colored('-----------',"$boldblack on_$bgcblack"); print colored('| ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored(' |',"$boldblack on_$bgcwhite"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldred on_$bgcred");print"\n";
	ruskieleft6();  print colored('----------',"$boldblack on_$bgcblack"); print colored('/\\ \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ /\\',"$boldblack on_$bgcwhite"); print colored('----------',"$boldblack on_$bgcblack");print colored('|                           |',"$boldred on_$bgcred");print"\n";
	ruskieleft7();  print colored('---',"$boldblack on_$bgcblack"); print colored('/ ____   \\______/   ____ \\',"$boldblack on_$bgcwhite"); print colored('---',"$boldblack on_$bgcblack");print colored('|',"$boldred on_$bgcred");print colored('  Win: 25 COINS            ',"$boldyellow on_$bgcred");print colored('|',"$boldred on_$bgcred");print"\n";
	ruskieleft8();  print colored('--',"$boldblack on_$bgcblack"); print colored('| /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\    ||||    /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\ |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|',"$boldred on_$bgcred");print colored(' Lose: YOUR LIFE           ',"$boldyellow on_$bgcred");print colored('|',"$boldred on_$bgcred");print"\n";
	ruskieleft9();  print colored('--',"$boldblack on_$bgcblack"); print colored('| ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ||||    ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored(' |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|                           |',"$boldred on_$bgcred");print"\n";
	ruskieleft10(); print colored('--',"$boldblack on_$bgcblack"); print colored('| \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/    ||||    \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|                           |',"$boldred on_$bgcred");print"\n";
 	ruskieleft11(); print colored('---',"$boldblack on_$bgcblack"); print colored('\\          ||||          /',"$boldblack on_$bgcwhite"); print colored('---',"$boldblack on_$bgcblack");print colored('|                           |',"$boldred on_$bgcred");print"\n";
	ruskieleft12(); print colored('----',"$boldblack on_$bgcblack"); print colored('>         ||||         <',"$boldblack on_$bgcwhite"); print colored('----',"$boldblack on_$bgcblack");print colored('|      ',"$boldred on_$bgcred"); ruskiebutton1(); print colored('      |',"$boldred on_$bgcred");print"\n";
	ruskieleft13(); print colored('---',"$boldblack on_$bgcblack"); print colored('/ ____     \__/     ____ \\',"$boldblack on_$bgcwhite");print colored('---',"$boldblack on_$bgcblack"); print colored('|      ',"$boldred on_$bgcred"); ruskiebutton2(); print colored('      |',"$boldred on_$bgcred");print"\n";
	ruskieleft14(); print colored('--',"$boldblack on_$bgcblack"); print colored('| /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\            /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\ |',"$boldblack on_$bgcwhite"); ;print colored('--',"$boldblack on_$bgcblack");print colored('|      ',"$boldred on_$bgcred"); ruskiebutton6(); print colored('      |',"$boldred on_$bgcred");print"\n";
	ruskieleft15(); print colored('--',"$boldblack on_$bgcblack"); print colored('| ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored(' >< ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored('            ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored(' |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|      ',"$boldred on_$bgcred"); ruskiebutton4(); print colored('      |',"$boldred on_$bgcred");print"\n";
	ruskieleft16(); print colored('--',"$boldblack on_$bgcblack"); print colored('| \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/    ____    \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ |',"$boldblack on_$bgcwhite");print colored('--',"$boldblack on_$bgcblack");print colored('|      ',"$boldred on_$bgcred"); ruskiebutton6(); print colored('      |',"$boldred on_$bgcred");  print"\n";
	ruskieleft17(); print colored('---',"$boldblack on_$bgcblack"); print colored('\\______   /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\   ______/',"$boldblack on_$bgcwhite");print colored('---',"$boldblack on_$bgcblack");  print colored('|      ',"$boldred on_$bgcred"); ruskiebutton6(); print colored('      |',"$boldred on_$bgcred");print"\n";
	ruskieleft18(); print colored('----------',"$boldblack on_$bgcblack"); print colored('\\  ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored('  /',"$boldblack on_$bgcwhite"); print colored('----------',"$boldblack on_$bgcblack");print colored('|      ',"$boldred on_$bgcred"); ruskiebutton7(); print colored('      |',"$boldred on_$bgcred"); print"\n";
	ruskieleft19(); print colored('-----------',"$boldblack on_$bgcblack"); print colored('\\ \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ /',"$boldblack on_$bgcwhite");print colored('-----------',"$boldblack on_$bgcblack");print colored('|      ',"$boldred on_$bgcred"); ruskiebutton8(); print colored('      |',"$boldred on_$bgcred");    print"\n";
	ruskieleft20(); print colored('------------',"$boldblack on_$bgcblack"); print colored('\\______/',"$boldblack on_$bgcwhite"); print colored('------------',"$boldblack on_$bgcblack");  print colored('|                           |',"$boldred on_$bgcred"); print"\n"; 
	ruskieleft21(); print colored('--------------------------------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldred on_$bgcred");print"\n";
	}
}

sub ruskie3rlv {
	if ($ruskieold == 1) {
	print colored('|                 |',"$boldmagenta on_$bgcmagenta"); print colored('--------------------------------',"$boldblack on_$bgcblack");print colored('|                           |',"$boldmagenta on_$bgcmagenta"); print"\n";
	print colored('|     2222222     |',"$boldmagenta on_$bgcmagenta"); print colored('---------------',"$boldblack on_$bgcblack"); print colored('/\\',"$boldblack on_$bgcwhite"); print colored('---------------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldmagenta on_$bgcmagenta");  print"\n";
	print colored('|  2222222222222  |',"$boldmagenta on_$bgcmagenta"); print colored('------------',"$boldblack on_$bgcblack"); print colored('/ ____ \\',"$boldblack on_$bgcwhite"); print colored('------------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldmagenta on_$bgcmagenta");  print"\n";
	print colored('| 222         222 |',"$boldmagenta on_$bgcmagenta"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('/ /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\ \\',"$boldblack on_$bgcwhite"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('|      25  or Your Life     |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|             222 |',"$boldmagenta on_$bgcmagenta"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('| ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored(' |',"$boldblack on_$bgcwhite"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|           2222  |',"$boldmagenta on_$bgcmagenta"); print colored('----------',"$boldblack on_$bgcblack"); print colored('/\\ \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ /\\',"$boldblack on_$bgcwhite"); print colored('----------',"$boldblack on_$bgcblack");print colored('|                           |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|         2222    |',"$boldmagenta on_$bgcmagenta"); print colored('---',"$boldblack on_$bgcblack"); print colored('/ ____   \\______/   ____ \\',"$boldblack on_$bgcwhite"); print colored('---',"$boldblack on_$bgcblack");print colored('|',"$boldmagenta on_$bgcmagenta");print colored('  Win: 25 COINS            ',"$boldyellow on_$bgcmagenta");print colored('|',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|       2222      |',"$boldmagenta on_$bgcmagenta"); print colored('--',"$boldblack on_$bgcblack"); print colored('| /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\    ||||    /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\ |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|',"$boldmagenta on_$bgcmagenta");print colored(' Lose: YOUR LIFE           ',"$boldyellow on_$bgcmagenta");print colored('|',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|     2222        |',"$boldmagenta on_$bgcmagenta"); print colored('--',"$boldblack on_$bgcblack"); print colored('| ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ||||    ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored(' |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|                           |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|   2222          |',"$boldmagenta on_$bgcmagenta"); print colored('--',"$boldblack on_$bgcblack"); print colored('| \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/    ||||    \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|                           |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('| 222222222222222 |',"$boldmagenta on_$bgcmagenta"); print colored('---',"$boldblack on_$bgcblack"); print colored('\\          ||||          /',"$boldblack on_$bgcwhite"); print colored('---',"$boldblack on_$bgcblack");print colored('|                           |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|                 |',"$boldmagenta on_$bgcmagenta"); print colored('----',"$boldblack on_$bgcblack"); print colored('>         ||||         <',"$boldblack on_$bgcwhite"); print colored('----',"$boldblack on_$bgcblack");print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored(' _____________  ',"$boldblack on_$bgcmagenta"); print colored('     |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('| 555555555555555 |',"$boldmagenta on_$bgcmagenta"); print colored('---',"$boldblack on_$bgcblack"); print colored('/ ____     \__/     ____ \\',"$boldblack on_$bgcwhite");print colored('---',"$boldblack on_$bgcblack"); print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored('|',"$boldblack on_$bgcmagenta"); print colored('|~~~~~~~~~~~|',"$boldred on_$bgcred");print colored('|',"$boldblack on_$bgcmagenta"); print colored('      |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('| 555555555555555 |',"$boldmagenta on_$bgcmagenta"); print colored('--',"$boldblack on_$bgcblack"); print colored('| /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\            /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\ |',"$boldblack on_$bgcwhite"); ;print colored('--',"$boldblack on_$bgcblack");print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored('|',"$boldblack on_$bgcmagenta"); print colored('|           |',"$boldred on_$bgcred");print colored('|',"$boldblack on_$bgcmagenta"); print colored('      |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('| 5555            |',"$boldmagenta on_$bgcmagenta"); print colored('--',"$boldblack on_$bgcblack"); print colored('| ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored('            ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored(' |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored('|',"$boldblack on_$bgcmagenta"); print colored('|   PRESS   |',"$boldred on_$bgcred");print colored('|',"$boldblack on_$bgcmagenta"); print colored('      |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('| 5555            |',"$boldmagenta on_$bgcmagenta"); print colored('--',"$boldblack on_$bgcblack"); print colored('| \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/    ____    \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ |',"$boldblack on_$bgcwhite");print colored('--',"$boldblack on_$bgcblack");print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored('|',"$boldblack on_$bgcmagenta"); print colored('|           |',"$boldred on_$bgcred");print colored('|',"$boldblack on_$bgcmagenta"); print colored('      |',"$boldmagenta on_$bgcmagenta");  print"\n";
	print colored('|  5555           |',"$boldmagenta on_$bgcmagenta"); print colored('---',"$boldblack on_$bgcblack"); print colored('\\______   /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\   ______/',"$boldblack on_$bgcwhite");print colored('---',"$boldblack on_$bgcblack");  print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored('|',"$boldblack on_$bgcmagenta"); print colored('|           |',"$boldred on_$bgcred");print colored('|',"$boldblack on_$bgcmagenta"); print colored('      |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|    55555555     |',"$boldmagenta on_$bgcmagenta"); print colored('----------',"$boldblack on_$bgcblack"); print colored('\\  ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored(' >< ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored('  /',"$boldblack on_$bgcwhite"); print colored('----------',"$boldblack on_$bgcblack");print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored('|',"$boldblack on_$bgcmagenta"); print colored('|___________|',"$boldred on_$bgcred");print colored('|',"$boldblack on_$bgcmagenta"); print colored('      |',"$boldmagenta on_$bgcmagenta"); print"\n";
	print colored('|      555555555  |',"$boldmagenta on_$bgcmagenta"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('\\ \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ /',"$boldblack on_$bgcwhite");print colored('-----------',"$boldblack on_$bgcblack");print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored(' ~~~~~~~~~~~~~  ',"$boldblack on_$bgcmagenta"); print colored('     |',"$boldmagenta on_$bgcmagenta");    print"\n";
	print colored('|            5555 |',"$boldmagenta on_$bgcmagenta"); print colored('------------',"$boldblack on_$bgcblack"); print colored('\\______/',"$boldblack on_$bgcwhite"); print colored('------------',"$boldblack on_$bgcblack");  print colored('|                           |',"$boldmagenta on_$bgcmagenta"); print"\n"; 
	print colored('|            5555 |',"$boldmagenta on_$bgcmagenta"); print colored('--------------------------------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldmagenta on_$bgcmagenta");print"\n";
	} else {
	ruskieleft1();  print colored('--------------------------------',"$boldblack on_$bgcblack");print colored('|                           |',"$boldred on_$bgcred"); print"\n";
	ruskieleft2();  print colored('---------------',"$boldblack on_$bgcblack"); print colored('/\\',"$boldblack on_$bgcwhite"); print colored('---------------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldred on_$bgcred");  print"\n";
	ruskieleft3();  print colored('------------',"$boldblack on_$bgcblack"); print colored('/ ____ \\',"$boldblack on_$bgcwhite"); print colored('------------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldred on_$bgcred");  print"\n";
	ruskieleft4();  print colored('-----------',"$boldblack on_$bgcblack"); print colored('/ /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\ \\',"$boldblack on_$bgcwhite"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('|      25  or Your Life     |',"$boldred on_$bgcred");print"\n";
	ruskieleft5();  print colored('-----------',"$boldblack on_$bgcblack"); print colored('| ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored(' |',"$boldblack on_$bgcwhite"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldred on_$bgcred");print"\n";
	ruskieleft6();  print colored('----------',"$boldblack on_$bgcblack"); print colored('/\\ \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ /\\',"$boldblack on_$bgcwhite"); print colored('----------',"$boldblack on_$bgcblack");print colored('|                           |',"$boldred on_$bgcred");print"\n";
	ruskieleft7();  print colored('---',"$boldblack on_$bgcblack"); print colored('/ ____   \\______/   ____ \\',"$boldblack on_$bgcwhite"); print colored('---',"$boldblack on_$bgcblack");print colored('|',"$boldred on_$bgcred");print colored('  Win: 25 COINS            ',"$boldyellow on_$bgcred");print colored('|',"$boldred on_$bgcred");print"\n";
	ruskieleft8();  print colored('--',"$boldblack on_$bgcblack"); print colored('| /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\    ||||    /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\ |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|',"$boldred on_$bgcred");print colored(' Lose: YOUR LIFE           ',"$boldyellow on_$bgcred");print colored('|',"$boldred on_$bgcred");print"\n";
	ruskieleft9();  print colored('--',"$boldblack on_$bgcblack"); print colored('| ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ||||    ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored(' |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|                           |',"$boldred on_$bgcred");print"\n";
	ruskieleft10(); print colored('--',"$boldblack on_$bgcblack"); print colored('| \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/    ||||    \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|                           |',"$boldred on_$bgcred");print"\n";
	ruskieleft11(); print colored('---',"$boldblack on_$bgcblack"); print colored('\\          ||||          /',"$boldblack on_$bgcwhite"); print colored('---',"$boldblack on_$bgcblack");print colored('|                           |',"$boldred on_$bgcred");print"\n";
	ruskieleft12(); print colored('----',"$boldblack on_$bgcblack"); print colored('>         ||||         <',"$boldblack on_$bgcwhite"); print colored('----',"$boldblack on_$bgcblack");print colored('|      ',"$boldred on_$bgcred"); ruskiebutton1(); print colored('      |',"$boldred on_$bgcred");print"\n";
	ruskieleft13(); print colored('---',"$boldblack on_$bgcblack"); print colored('/ ____     \__/     ____ \\',"$boldblack on_$bgcwhite");print colored('---',"$boldblack on_$bgcblack"); print colored('|      ',"$boldred on_$bgcred"); ruskiebutton2(); print colored('      |',"$boldred on_$bgcred");print"\n";
	ruskieleft14(); print colored('--',"$boldblack on_$bgcblack"); print colored('| /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\            /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\ |',"$boldblack on_$bgcwhite"); ;print colored('--',"$boldblack on_$bgcblack");print colored('|      ',"$boldred on_$bgcred"); ruskiebutton6(); print colored('      |',"$boldred on_$bgcred");print"\n";
	ruskieleft15(); print colored('--',"$boldblack on_$bgcblack"); print colored('| ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored('            ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored(' |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|      ',"$boldred on_$bgcred"); ruskiebutton4(); print colored('      |',"$boldred on_$bgcred");print"\n";
	ruskieleft16(); print colored('--',"$boldblack on_$bgcblack"); print colored('| \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/    ____    \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ |',"$boldblack on_$bgcwhite");print colored('--',"$boldblack on_$bgcblack");print colored('|      ',"$boldred on_$bgcred"); ruskiebutton6(); print colored('      |',"$boldred on_$bgcred");  print"\n";
	ruskieleft17(); print colored('---',"$boldblack on_$bgcblack"); print colored('\\______   /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\   ______/',"$boldblack on_$bgcwhite");print colored('---',"$boldblack on_$bgcblack");  print colored('|      ',"$boldred on_$bgcred"); ruskiebutton6(); print colored('      |',"$boldred on_$bgcred");print"\n";
	ruskieleft18(); print colored('----------',"$boldblack on_$bgcblack"); print colored('\\  ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored(' >< ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored('  /',"$boldblack on_$bgcwhite"); print colored('----------',"$boldblack on_$bgcblack");print colored('|      ',"$boldred on_$bgcred"); ruskiebutton7(); print colored('      |',"$boldred on_$bgcred"); print"\n";
	ruskieleft19(); print colored('-----------',"$boldblack on_$bgcblack"); print colored('\\ \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ /',"$boldblack on_$bgcwhite");print colored('-----------',"$boldblack on_$bgcblack");print colored('|      ',"$boldred on_$bgcred"); ruskiebutton8(); print colored('      |',"$boldred on_$bgcred");    print"\n";
	ruskieleft20(); print colored('------------',"$boldblack on_$bgcblack"); print colored('\\______/',"$boldblack on_$bgcwhite"); print colored('------------',"$boldblack on_$bgcblack");  print colored('|                           |',"$boldred on_$bgcred"); print"\n"; 
	ruskieleft21(); print colored('--------------------------------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldred on_$bgcred");print"\n";
	}
}

sub ruskie4rlv {	
	if ($ruskieold == 1) {
	print colored('|                 |',"$boldmagenta on_$bgcmagenta"); print colored('--------------------------------',"$boldblack on_$bgcblack");print colored('|                           |',"$boldmagenta on_$bgcmagenta"); print"\n";
	print colored('|     2222222     |',"$boldmagenta on_$bgcmagenta"); print colored('---------------',"$boldblack on_$bgcblack"); print colored('/\\',"$boldblack on_$bgcwhite"); print colored('---------------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldmagenta on_$bgcmagenta");  print"\n";
	print colored('|  2222222222222  |',"$boldmagenta on_$bgcmagenta"); print colored('------------',"$boldblack on_$bgcblack"); print colored('/ ____ \\',"$boldblack on_$bgcwhite"); print colored('------------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldmagenta on_$bgcmagenta");  print"\n";
	print colored('| 222         222 |',"$boldmagenta on_$bgcmagenta"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('/ /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\ \\',"$boldblack on_$bgcwhite"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('|      25  or Your Life     |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|             222 |',"$boldmagenta on_$bgcmagenta"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('| ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored(' |',"$boldblack on_$bgcwhite"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|           2222  |',"$boldmagenta on_$bgcmagenta"); print colored('----------',"$boldblack on_$bgcblack"); print colored('/\\ \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ /\\',"$boldblack on_$bgcwhite"); print colored('----------',"$boldblack on_$bgcblack");print colored('|                           |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|         2222    |',"$boldmagenta on_$bgcmagenta"); print colored('---',"$boldblack on_$bgcblack"); print colored('/ ____   \\______/   ____ \\',"$boldblack on_$bgcwhite"); print colored('---',"$boldblack on_$bgcblack");print colored('|',"$boldmagenta on_$bgcmagenta");print colored('  Win: 25 COINS            ',"$boldyellow on_$bgcmagenta");print colored('|',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|       2222      |',"$boldmagenta on_$bgcmagenta"); print colored('--',"$boldblack on_$bgcblack"); print colored('| /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\    ||||    /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\ |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|',"$boldmagenta on_$bgcmagenta");print colored(' Lose: YOUR LIFE           ',"$boldyellow on_$bgcmagenta");print colored('|',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|     2222        |',"$boldmagenta on_$bgcmagenta"); print colored('--',"$boldblack on_$bgcblack"); print colored('| ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ||||    ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored(' |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|                           |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|   2222          |',"$boldmagenta on_$bgcmagenta"); print colored('--',"$boldblack on_$bgcblack"); print colored('| \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/    ||||    \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|                           |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('| 222222222222222 |',"$boldmagenta on_$bgcmagenta"); print colored('---',"$boldblack on_$bgcblack"); print colored('\\          ||||          /',"$boldblack on_$bgcwhite"); print colored('---',"$boldblack on_$bgcblack");print colored('|                           |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|                 |',"$boldmagenta on_$bgcmagenta"); print colored('----',"$boldblack on_$bgcblack"); print colored('>         ||||         <',"$boldblack on_$bgcwhite"); print colored('----',"$boldblack on_$bgcblack");print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored(' _____________  ',"$boldblack on_$bgcmagenta"); print colored('     |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('| 555555555555555 |',"$boldmagenta on_$bgcmagenta"); print colored('---',"$boldblack on_$bgcblack"); print colored('/ ____     \__/     ____ \\',"$boldblack on_$bgcwhite");print colored('---',"$boldblack on_$bgcblack"); print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored('|',"$boldblack on_$bgcmagenta"); print colored('|~~~~~~~~~~~|',"$boldred on_$bgcred");print colored('|',"$boldblack on_$bgcmagenta"); print colored('      |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('| 555555555555555 |',"$boldmagenta on_$bgcmagenta"); print colored('--',"$boldblack on_$bgcblack"); print colored('| /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\            /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\ |',"$boldblack on_$bgcwhite"); ;print colored('--',"$boldblack on_$bgcblack");print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored('|',"$boldblack on_$bgcmagenta"); print colored('|           |',"$boldred on_$bgcred");print colored('|',"$boldblack on_$bgcmagenta"); print colored('      |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('| 5555            |',"$boldmagenta on_$bgcmagenta"); print colored('--',"$boldblack on_$bgcblack"); print colored('| ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored('            ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored(' >< ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored(' |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored('|',"$boldblack on_$bgcmagenta"); print colored('|   PRESS   |',"$boldred on_$bgcred");print colored('|',"$boldblack on_$bgcmagenta"); print colored('      |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('| 5555            |',"$boldmagenta on_$bgcmagenta"); print colored('--',"$boldblack on_$bgcblack"); print colored('| \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/    ____    \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ |',"$boldblack on_$bgcwhite");print colored('--',"$boldblack on_$bgcblack");print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored('|',"$boldblack on_$bgcmagenta"); print colored('|           |',"$boldred on_$bgcred");print colored('|',"$boldblack on_$bgcmagenta"); print colored('      |',"$boldmagenta on_$bgcmagenta");  print"\n";
	print colored('|  5555           |',"$boldmagenta on_$bgcmagenta"); print colored('---',"$boldblack on_$bgcblack"); print colored('\\______   /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\   ______/',"$boldblack on_$bgcwhite");print colored('---',"$boldblack on_$bgcblack");  print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored('|',"$boldblack on_$bgcmagenta"); print colored('|           |',"$boldred on_$bgcred");print colored('|',"$boldblack on_$bgcmagenta"); print colored('      |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|    55555555     |',"$boldmagenta on_$bgcmagenta"); print colored('----------',"$boldblack on_$bgcblack"); print colored('\\  ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored('  /',"$boldblack on_$bgcwhite"); print colored('----------',"$boldblack on_$bgcblack");print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored('|',"$boldblack on_$bgcmagenta"); print colored('|___________|',"$boldred on_$bgcred");print colored('|',"$boldblack on_$bgcmagenta"); print colored('      |',"$boldmagenta on_$bgcmagenta"); print"\n";
	print colored('|      555555555  |',"$boldmagenta on_$bgcmagenta"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('\\ \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ /',"$boldblack on_$bgcwhite");print colored('-----------',"$boldblack on_$bgcblack");print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored(' ~~~~~~~~~~~~~  ',"$boldblack on_$bgcmagenta"); print colored('     |',"$boldmagenta on_$bgcmagenta");    print"\n";
	print colored('|            5555 |',"$boldmagenta on_$bgcmagenta"); print colored('------------',"$boldblack on_$bgcblack"); print colored('\\______/',"$boldblack on_$bgcwhite"); print colored('------------',"$boldblack on_$bgcblack");  print colored('|                           |',"$boldmagenta on_$bgcmagenta"); print"\n"; 
	print colored('|            5555 |',"$boldmagenta on_$bgcmagenta"); print colored('--------------------------------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldmagenta on_$bgcmagenta");print"\n";
	} else {
	ruskieleft1();  print colored('--------------------------------',"$boldblack on_$bgcblack");print colored('|                           |',"$boldred on_$bgcred"); print"\n";
	ruskieleft2();  print colored('---------------',"$boldblack on_$bgcblack"); print colored('/\\',"$boldblack on_$bgcwhite"); print colored('---------------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldred on_$bgcred");  print"\n";
	ruskieleft3();  print colored('------------',"$boldblack on_$bgcblack"); print colored('/ ____ \\',"$boldblack on_$bgcwhite"); print colored('------------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldred on_$bgcred");  print"\n";
	ruskieleft4();  print colored('-----------',"$boldblack on_$bgcblack"); print colored('/ /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\ \\',"$boldblack on_$bgcwhite"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('|      25  or Your Life     |',"$boldred on_$bgcred");print"\n";
	ruskieleft5();  print colored('-----------',"$boldblack on_$bgcblack"); print colored('| ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored(' |',"$boldblack on_$bgcwhite"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldred on_$bgcred");print"\n";
	ruskieleft6();  print colored('----------',"$boldblack on_$bgcblack"); print colored('/\\ \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ /\\',"$boldblack on_$bgcwhite"); print colored('----------',"$boldblack on_$bgcblack");print colored('|                           |',"$boldred on_$bgcred");print"\n";
	ruskieleft7();  print colored('---',"$boldblack on_$bgcblack"); print colored('/ ____   \\______/   ____ \\',"$boldblack on_$bgcwhite"); print colored('---',"$boldblack on_$bgcblack");print colored('|',"$boldred on_$bgcred");print colored('  Win: 25 COINS            ',"$boldyellow on_$bgcred");print colored('|',"$boldred on_$bgcred");print"\n";
	ruskieleft8();  print colored('--',"$boldblack on_$bgcblack"); print colored('| /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\    ||||    /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\ |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|',"$boldred on_$bgcred");print colored(' Lose: YOUR LIFE           ',"$boldyellow on_$bgcred");print colored('|',"$boldred on_$bgcred");print"\n";
	ruskieleft9();  print colored('--',"$boldblack on_$bgcblack"); print colored('| ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ||||    ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored(' |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|                           |',"$boldred on_$bgcred");print"\n";
	ruskieleft10(); print colored('--',"$boldblack on_$bgcblack"); print colored('| \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/    ||||    \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|                           |',"$boldred on_$bgcred");print"\n";
	ruskieleft11(); print colored('---',"$boldblack on_$bgcblack"); print colored('\\          ||||          /',"$boldblack on_$bgcwhite"); print colored('---',"$boldblack on_$bgcblack");print colored('|                           |',"$boldred on_$bgcred");print"\n";
	ruskieleft12(); print colored('----',"$boldblack on_$bgcblack"); print colored('>         ||||         <',"$boldblack on_$bgcwhite"); print colored('----',"$boldblack on_$bgcblack");print colored('|      ',"$boldred on_$bgcred"); ruskiebutton1(); print colored('      |',"$boldred on_$bgcred");print"\n";
	ruskieleft13(); print colored('---',"$boldblack on_$bgcblack"); print colored('/ ____     \__/     ____ \\',"$boldblack on_$bgcwhite");print colored('---',"$boldblack on_$bgcblack"); print colored('|      ',"$boldred on_$bgcred"); ruskiebutton2(); print colored('      |',"$boldred on_$bgcred");print"\n";
	ruskieleft14(); print colored('--',"$boldblack on_$bgcblack"); print colored('| /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\            /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\ |',"$boldblack on_$bgcwhite"); ;print colored('--',"$boldblack on_$bgcblack");print colored('|      ',"$boldred on_$bgcred"); ruskiebutton6(); print colored('      |',"$boldred on_$bgcred");print"\n";
	ruskieleft15(); print colored('--',"$boldblack on_$bgcblack"); print colored('| ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored('            ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored(' >< ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored(' |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|      ',"$boldred on_$bgcred"); ruskiebutton4(); print colored('      |',"$boldred on_$bgcred");print"\n";
	ruskieleft16(); print colored('--',"$boldblack on_$bgcblack"); print colored('| \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/    ____    \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ |',"$boldblack on_$bgcwhite");print colored('--',"$boldblack on_$bgcblack");print colored('|      ',"$boldred on_$bgcred"); ruskiebutton6(); print colored('      |',"$boldred on_$bgcred");  print"\n";
	ruskieleft17(); print colored('---',"$boldblack on_$bgcblack"); print colored('\\______   /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\   ______/',"$boldblack on_$bgcwhite");print colored('---',"$boldblack on_$bgcblack");  print colored('|      ',"$boldred on_$bgcred"); ruskiebutton6(); print colored('      |',"$boldred on_$bgcred");print"\n";
	ruskieleft18(); print colored('----------',"$boldblack on_$bgcblack"); print colored('\\  ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored('  /',"$boldblack on_$bgcwhite"); print colored('----------',"$boldblack on_$bgcblack");print colored('|      ',"$boldred on_$bgcred"); ruskiebutton7(); print colored('      |',"$boldred on_$bgcred"); print"\n";
	ruskieleft19(); print colored('-----------',"$boldblack on_$bgcblack"); print colored('\\ \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ /',"$boldblack on_$bgcwhite");print colored('-----------',"$boldblack on_$bgcblack");print colored('|      ',"$boldred on_$bgcred"); ruskiebutton8(); print colored('      |',"$boldred on_$bgcred");    print"\n";
	ruskieleft20(); print colored('------------',"$boldblack on_$bgcblack"); print colored('\\______/',"$boldblack on_$bgcwhite"); print colored('------------',"$boldblack on_$bgcblack");  print colored('|                           |',"$boldred on_$bgcred"); print"\n"; 
	ruskieleft21(); print colored('--------------------------------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldred on_$bgcred");print"\n";
	}
}

sub ruskie5rlv {
	if ($ruskieold == 1) {
	print colored('|                 |',"$boldmagenta on_$bgcmagenta"); print colored('--------------------------------',"$boldblack on_$bgcblack");print colored('|                           |',"$boldmagenta on_$bgcmagenta"); print"\n";
	print colored('|     2222222     |',"$boldmagenta on_$bgcmagenta"); print colored('---------------',"$boldblack on_$bgcblack"); print colored('/\\',"$boldblack on_$bgcwhite"); print colored('---------------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldmagenta on_$bgcmagenta");  print"\n";
	print colored('|  2222222222222  |',"$boldmagenta on_$bgcmagenta"); print colored('------------',"$boldblack on_$bgcblack"); print colored('/ ____ \\',"$boldblack on_$bgcwhite"); print colored('------------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldmagenta on_$bgcmagenta");  print"\n";
	print colored('| 222         222 |',"$boldmagenta on_$bgcmagenta"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('/ /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\ \\',"$boldblack on_$bgcwhite"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('|      25  or Your Life     |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|             222 |',"$boldmagenta on_$bgcmagenta"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('| ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored(' |',"$boldblack on_$bgcwhite"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|           2222  |',"$boldmagenta on_$bgcmagenta"); print colored('----------',"$boldblack on_$bgcblack"); print colored('/\\ \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ /\\',"$boldblack on_$bgcwhite"); print colored('----------',"$boldblack on_$bgcblack");print colored('|                           |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|         2222    |',"$boldmagenta on_$bgcmagenta"); print colored('---',"$boldblack on_$bgcblack"); print colored('/ ____   \\______/   ____ \\',"$boldblack on_$bgcwhite"); print colored('---',"$boldblack on_$bgcblack");print colored('|',"$boldmagenta on_$bgcmagenta");print colored('  Win: 25 COINS            ',"$boldyellow on_$bgcmagenta");print colored('|',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|       2222      |',"$boldmagenta on_$bgcmagenta"); print colored('--',"$boldblack on_$bgcblack"); print colored('| /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\    ||||    /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\ |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|',"$boldmagenta on_$bgcmagenta");print colored(' Lose: YOUR LIFE           ',"$boldyellow on_$bgcmagenta");print colored('|',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|     2222        |',"$boldmagenta on_$bgcmagenta"); print colored('--',"$boldblack on_$bgcblack"); print colored('| ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ||||    ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored(' >< ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored(' |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|                           |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|   2222          |',"$boldmagenta on_$bgcmagenta"); print colored('--',"$boldblack on_$bgcblack"); print colored('| \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/    ||||    \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|                           |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('| 222222222222222 |',"$boldmagenta on_$bgcmagenta"); print colored('---',"$boldblack on_$bgcblack"); print colored('\\          ||||          /',"$boldblack on_$bgcwhite"); print colored('---',"$boldblack on_$bgcblack");print colored('|                           |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|                 |',"$boldmagenta on_$bgcmagenta"); print colored('----',"$boldblack on_$bgcblack"); print colored('>         ||||         <',"$boldblack on_$bgcwhite"); print colored('----',"$boldblack on_$bgcblack");print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored(' _____________  ',"$boldblack on_$bgcmagenta"); print colored('     |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('| 555555555555555 |',"$boldmagenta on_$bgcmagenta"); print colored('---',"$boldblack on_$bgcblack"); print colored('/ ____     \__/     ____ \\',"$boldblack on_$bgcwhite");print colored('---',"$boldblack on_$bgcblack"); print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored('|',"$boldblack on_$bgcmagenta"); print colored('|~~~~~~~~~~~|',"$boldred on_$bgcred");print colored('|',"$boldblack on_$bgcmagenta"); print colored('      |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('| 555555555555555 |',"$boldmagenta on_$bgcmagenta"); print colored('--',"$boldblack on_$bgcblack"); print colored('| /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\            /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\ |',"$boldblack on_$bgcwhite"); ;print colored('--',"$boldblack on_$bgcblack");print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored('|',"$boldblack on_$bgcmagenta"); print colored('|           |',"$boldred on_$bgcred");print colored('|',"$boldblack on_$bgcmagenta"); print colored('      |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('| 5555            |',"$boldmagenta on_$bgcmagenta"); print colored('--',"$boldblack on_$bgcblack"); print colored('| ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored('            ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored(' |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored('|',"$boldblack on_$bgcmagenta"); print colored('|   PRESS   |',"$boldred on_$bgcred");print colored('|',"$boldblack on_$bgcmagenta"); print colored('      |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('| 5555            |',"$boldmagenta on_$bgcmagenta"); print colored('--',"$boldblack on_$bgcblack"); print colored('| \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/    ____    \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ |',"$boldblack on_$bgcwhite");print colored('--',"$boldblack on_$bgcblack");print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored('|',"$boldblack on_$bgcmagenta"); print colored('|           |',"$boldred on_$bgcred");print colored('|',"$boldblack on_$bgcmagenta"); print colored('      |',"$boldmagenta on_$bgcmagenta");  print"\n";
	print colored('|  5555           |',"$boldmagenta on_$bgcmagenta"); print colored('---',"$boldblack on_$bgcblack"); print colored('\\______   /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\   ______/',"$boldblack on_$bgcwhite");print colored('---',"$boldblack on_$bgcblack");  print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored('|',"$boldblack on_$bgcmagenta"); print colored('|           |',"$boldred on_$bgcred");print colored('|',"$boldblack on_$bgcmagenta"); print colored('      |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|    55555555     |',"$boldmagenta on_$bgcmagenta"); print colored('----------',"$boldblack on_$bgcblack"); print colored('\\  ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored('  /',"$boldblack on_$bgcwhite"); print colored('----------',"$boldblack on_$bgcblack");print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored('|',"$boldblack on_$bgcmagenta"); print colored('|___________|',"$boldred on_$bgcred");print colored('|',"$boldblack on_$bgcmagenta"); print colored('      |',"$boldmagenta on_$bgcmagenta"); print"\n";
	print colored('|      555555555  |',"$boldmagenta on_$bgcmagenta"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('\\ \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ /',"$boldblack on_$bgcwhite");print colored('-----------',"$boldblack on_$bgcblack");print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored(' ~~~~~~~~~~~~~  ',"$boldblack on_$bgcmagenta"); print colored('     |',"$boldmagenta on_$bgcmagenta");    print"\n";
	print colored('|            5555 |',"$boldmagenta on_$bgcmagenta"); print colored('------------',"$boldblack on_$bgcblack"); print colored('\\______/',"$boldblack on_$bgcwhite"); print colored('------------',"$boldblack on_$bgcblack");  print colored('|                           |',"$boldmagenta on_$bgcmagenta"); print"\n"; 
	print colored('|            5555 |',"$boldmagenta on_$bgcmagenta"); print colored('--------------------------------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldmagenta on_$bgcmagenta");print"\n";
	} else {
	ruskieleft1();  print colored('--------------------------------',"$boldblack on_$bgcblack");print colored('|                           |',"$boldred on_$bgcred"); print"\n";
	ruskieleft2();  print colored('---------------',"$boldblack on_$bgcblack"); print colored('/\\',"$boldblack on_$bgcwhite"); print colored('---------------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldred on_$bgcred");  print"\n";
	ruskieleft3();  print colored('------------',"$boldblack on_$bgcblack"); print colored('/ ____ \\',"$boldblack on_$bgcwhite"); print colored('------------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldred on_$bgcred");  print"\n";
	ruskieleft4();  print colored('-----------',"$boldblack on_$bgcblack"); print colored('/ /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\ \\',"$boldblack on_$bgcwhite"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('|      25  or Your Life     |',"$boldred on_$bgcred");print"\n";
	ruskieleft5();  print colored('-----------',"$boldblack on_$bgcblack"); print colored('| ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored(' |',"$boldblack on_$bgcwhite"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldred on_$bgcred");print"\n";
	ruskieleft6();  print colored('----------',"$boldblack on_$bgcblack"); print colored('/\\ \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ /\\',"$boldblack on_$bgcwhite"); print colored('----------',"$boldblack on_$bgcblack");print colored('|                           |',"$boldred on_$bgcred");print"\n";
	ruskieleft7();  print colored('---',"$boldblack on_$bgcblack"); print colored('/ ____   \\______/   ____ \\',"$boldblack on_$bgcwhite"); print colored('---',"$boldblack on_$bgcblack");print colored('|',"$boldred on_$bgcred");print colored('  Win: 25 COINS            ',"$boldyellow on_$bgcred");print colored('|',"$boldred on_$bgcred");print"\n";
	ruskieleft8();  print colored('--',"$boldblack on_$bgcblack"); print colored('| /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\    ||||    /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\ |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|',"$boldred on_$bgcred");print colored(' Lose: YOUR LIFE           ',"$boldyellow on_$bgcred");print colored('|',"$boldred on_$bgcred");print"\n";
	ruskieleft9();  print colored('--',"$boldblack on_$bgcblack"); print colored('| ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ||||    ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored(' >< ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored(' |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|                           |',"$boldred on_$bgcred");print"\n";
	ruskieleft10(); print colored('--',"$boldblack on_$bgcblack"); print colored('| \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/    ||||    \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|                           |',"$boldred on_$bgcred");print"\n";
	ruskieleft11(); print colored('---',"$boldblack on_$bgcblack"); print colored('\\          ||||          /',"$boldblack on_$bgcwhite"); print colored('---',"$boldblack on_$bgcblack");print colored('|                           |',"$boldred on_$bgcred");print"\n";
	ruskieleft12(); print colored('----',"$boldblack on_$bgcblack"); print colored('>         ||||         <',"$boldblack on_$bgcwhite"); print colored('----',"$boldblack on_$bgcblack");print colored('|      ',"$boldred on_$bgcred"); ruskiebutton1(); print colored('      |',"$boldred on_$bgcred");print"\n";
	ruskieleft13(); print colored('---',"$boldblack on_$bgcblack"); print colored('/ ____     \__/     ____ \\',"$boldblack on_$bgcwhite");print colored('---',"$boldblack on_$bgcblack"); print colored('|      ',"$boldred on_$bgcred"); ruskiebutton2(); print colored('      |',"$boldred on_$bgcred");print"\n";
	ruskieleft14(); print colored('--',"$boldblack on_$bgcblack"); print colored('| /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\            /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\ |',"$boldblack on_$bgcwhite"); ;print colored('--',"$boldblack on_$bgcblack");print colored('|      ',"$boldred on_$bgcred"); ruskiebutton6(); print colored('      |',"$boldred on_$bgcred");print"\n";
	ruskieleft15(); print colored('--',"$boldblack on_$bgcblack"); print colored('| ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored('            ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored(' |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|      ',"$boldred on_$bgcred"); ruskiebutton4(); print colored('      |',"$boldred on_$bgcred");print"\n";
	ruskieleft16(); print colored('--',"$boldblack on_$bgcblack"); print colored('| \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/    ____    \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ |',"$boldblack on_$bgcwhite");print colored('--',"$boldblack on_$bgcblack");print colored('|      ',"$boldred on_$bgcred"); ruskiebutton6(); print colored('      |',"$boldred on_$bgcred");  print"\n";
	ruskieleft17(); print colored('---',"$boldblack on_$bgcblack"); print colored('\\______   /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\   ______/',"$boldblack on_$bgcwhite");print colored('---',"$boldblack on_$bgcblack");  print colored('|      ',"$boldred on_$bgcred"); ruskiebutton6(); print colored('      |',"$boldred on_$bgcred");print"\n";
	ruskieleft18(); print colored('----------',"$boldblack on_$bgcblack"); print colored('\\  ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored('  /',"$boldblack on_$bgcwhite"); print colored('----------',"$boldblack on_$bgcblack");print colored('|      ',"$boldred on_$bgcred"); ruskiebutton7(); print colored('      |',"$boldred on_$bgcred"); print"\n";
	ruskieleft19(); print colored('-----------',"$boldblack on_$bgcblack"); print colored('\\ \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ /',"$boldblack on_$bgcwhite");print colored('-----------',"$boldblack on_$bgcblack");print colored('|      ',"$boldred on_$bgcred"); ruskiebutton8(); print colored('      |',"$boldred on_$bgcred");    print"\n";
	ruskieleft20(); print colored('------------',"$boldblack on_$bgcblack"); print colored('\\______/',"$boldblack on_$bgcwhite"); print colored('------------',"$boldblack on_$bgcblack");  print colored('|                           |',"$boldred on_$bgcred"); print"\n"; 
	ruskieleft21(); print colored('--------------------------------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldred on_$bgcred");print"\n";
	}
}

sub ruskie6rlv {
	if ($ruskieold == 1) {
	print colored('|                 |',"$boldmagenta on_$bgcmagenta"); print colored('--------------------------------',"$boldblack on_$bgcblack");print colored('|                           |',"$boldmagenta on_$bgcmagenta"); print"\n";
	print colored('|     2222222     |',"$boldmagenta on_$bgcmagenta"); print colored('---------------',"$boldblack on_$bgcblack"); print colored('/\\',"$boldblack on_$bgcwhite"); print colored('---------------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldmagenta on_$bgcmagenta");  print"\n";
	print colored('|  2222222222222  |',"$boldmagenta on_$bgcmagenta"); print colored('------------',"$boldblack on_$bgcblack"); print colored('/ ____ \\',"$boldblack on_$bgcwhite"); print colored('------------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldmagenta on_$bgcmagenta");  print"\n";
	print colored('| 222         222 |',"$boldmagenta on_$bgcmagenta"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('/ /',"$boldblack on_$bgcwhite"); print colored('.*,X',"$boldyellow on_$bgcred"); print colored('\ \\',"$boldblack on_$bgcwhite"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('|      25  or Your Life     |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|             222 |',"$boldmagenta on_$bgcmagenta"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('| ',"$boldblack on_$bgcwhite"); print colored('',"$boldblack on_$bgcwhite"); print colored('|*>~>|',"$boldyellow on_$bgcred");  print colored(' |',"$boldblack on_$bgcwhite"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|           2222  |',"$boldmagenta on_$bgcmagenta"); print colored('----------',"$boldblack on_$bgcblack"); print colored('/\\ \\',"$boldblack on_$bgcwhite"); print colored('x\/#',"$boldyellow on_$bgcred"); print colored('/ /\\',"$boldblack on_$bgcwhite"); print colored('----------',"$boldblack on_$bgcblack");print colored('|                           |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|         2222    |',"$boldmagenta on_$bgcmagenta"); print colored('---',"$boldblack on_$bgcblack"); print colored('/ ____   \\______/   ____ \\',"$boldblack on_$bgcwhite"); print colored('---',"$boldblack on_$bgcblack");print colored('|',"$boldmagenta on_$bgcmagenta");print colored('  Win: 25 COINS            ',"$boldyellow on_$bgcmagenta");print colored('|',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|       2222      |',"$boldmagenta on_$bgcmagenta"); print colored('--',"$boldblack on_$bgcblack"); print colored('| /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\    ||||    /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\ |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|',"$boldmagenta on_$bgcmagenta");print colored(' Lose: YOUR LIFE           ',"$boldyellow on_$bgcmagenta");print colored('|',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|     2222        |',"$boldmagenta on_$bgcmagenta"); print colored('--',"$boldblack on_$bgcblack"); print colored('| ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ||||    ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored(' |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|                           |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|   2222          |',"$boldmagenta on_$bgcmagenta"); print colored('--',"$boldblack on_$bgcblack"); print colored('| \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/    ||||    \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|                           |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('| 222222222222222 |',"$boldmagenta on_$bgcmagenta"); print colored('---',"$boldblack on_$bgcblack"); print colored('\\          ||||          /',"$boldblack on_$bgcwhite"); print colored('---',"$boldblack on_$bgcblack");print colored('|                           |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|                 |',"$boldmagenta on_$bgcmagenta"); print colored('----',"$boldblack on_$bgcblack"); print colored('>         ||||         <',"$boldblack on_$bgcwhite"); print colored('----',"$boldblack on_$bgcblack");print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored(' _____________  ',"$boldblack on_$bgcmagenta"); print colored('     |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('| 555555555555555 |',"$boldmagenta on_$bgcmagenta"); print colored('---',"$boldblack on_$bgcblack"); print colored('/ ____     \__/     ____ \\',"$boldblack on_$bgcwhite");print colored('---',"$boldblack on_$bgcblack"); print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored('|',"$boldblack on_$bgcmagenta"); print colored('|~~~~~~~~~~~|',"$boldred on_$bgcred");print colored('|',"$boldblack on_$bgcmagenta"); print colored('      |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('| 555555555555555 |',"$boldmagenta on_$bgcmagenta"); print colored('--',"$boldblack on_$bgcblack"); print colored('| /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\            /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\ |',"$boldblack on_$bgcwhite"); ;print colored('--',"$boldblack on_$bgcblack");print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored('|',"$boldblack on_$bgcmagenta"); print colored('|           |',"$boldred on_$bgcred");print colored('|',"$boldblack on_$bgcmagenta"); print colored('      |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('| 5555            |',"$boldmagenta on_$bgcmagenta"); print colored('--',"$boldblack on_$bgcblack"); print colored('| ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored('            ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored(' |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored('|',"$boldblack on_$bgcmagenta"); print colored('|   PRESS   |',"$boldred on_$bgcred");print colored('|',"$boldblack on_$bgcmagenta"); print colored('      |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('| 5555            |',"$boldmagenta on_$bgcmagenta"); print colored('--',"$boldblack on_$bgcblack"); print colored('| \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/    ____    \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ |',"$boldblack on_$bgcwhite");print colored('--',"$boldblack on_$bgcblack");print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored('|',"$boldblack on_$bgcmagenta"); print colored('|           |',"$boldred on_$bgcred");print colored('|',"$boldblack on_$bgcmagenta"); print colored('      |',"$boldmagenta on_$bgcmagenta");  print"\n";
	print colored('|  5555           |',"$boldmagenta on_$bgcmagenta"); print colored('---',"$boldblack on_$bgcblack"); print colored('\\______   /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\   ______/',"$boldblack on_$bgcwhite");print colored('---',"$boldblack on_$bgcblack");  print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored('|',"$boldblack on_$bgcmagenta"); print colored('|           |',"$boldred on_$bgcred");print colored('|',"$boldblack on_$bgcmagenta"); print colored('      |',"$boldmagenta on_$bgcmagenta");print"\n";
	print colored('|    55555555     |',"$boldmagenta on_$bgcmagenta"); print colored('----------',"$boldblack on_$bgcblack"); print colored('\\  ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored('  /',"$boldblack on_$bgcwhite"); print colored('----------',"$boldblack on_$bgcblack");print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored('|',"$boldblack on_$bgcmagenta"); print colored('|___________|',"$boldred on_$bgcred");print colored('|',"$boldblack on_$bgcmagenta"); print colored('      |',"$boldmagenta on_$bgcmagenta"); print"\n";
	print colored('|      555555555  |',"$boldmagenta on_$bgcmagenta"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('\\ \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ /',"$boldblack on_$bgcwhite");print colored('-----------',"$boldblack on_$bgcblack");print colored('|      ',"$boldmagenta on_$bgcmagenta"); print colored(' ~~~~~~~~~~~~~  ',"$boldblack on_$bgcmagenta"); print colored('     |',"$boldmagenta on_$bgcmagenta");    print"\n";
	print colored('|            5555 |',"$boldmagenta on_$bgcmagenta"); print colored('------------',"$boldblack on_$bgcblack"); print colored('\\______/',"$boldblack on_$bgcwhite"); print colored('------------',"$boldblack on_$bgcblack");  print colored('|                           |',"$boldmagenta on_$bgcmagenta"); print"\n"; 
	print colored('|            5555 |',"$boldmagenta on_$bgcmagenta"); print colored('--------------------------------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldmagenta on_$bgcmagenta");print"\n";
	} else {
	ruskieleft1();  print colored('--------------------------------',"$boldblack on_$bgcblack");print colored('|                           |',"$boldred on_$bgcred"); print"\n";
	ruskieleft2();  print colored('---------------',"$boldblack on_$bgcblack"); print colored('/\\',"$boldblack on_$bgcwhite"); print colored('---------------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldred on_$bgcred");  print"\n";
	ruskieleft3();  print colored('------------',"$boldblack on_$bgcblack"); print colored('/ ____ \\',"$boldblack on_$bgcwhite"); print colored('------------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldred on_$bgcred");  print"\n";
	ruskieleft4();  print colored('-----------',"$boldblack on_$bgcblack"); print colored('/ /',"$boldblack on_$bgcwhite"); print colored('.*,X',"$boldyellow on_$bgcred"); print colored('\ \\',"$boldblack on_$bgcwhite"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('|      25  or Your Life     |',"$boldred on_$bgcred");print"\n";
	ruskieleft5();  print colored('-----------',"$boldblack on_$bgcblack"); print colored('| ',"$boldblack on_$bgcwhite"); print colored('',"$boldblack on_$bgcwhite"); print colored('|*>~>|',"$boldyellow on_$bgcred");  print colored(' |',"$boldblack on_$bgcwhite"); print colored('-----------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldred on_$bgcred");print"\n";
	ruskieleft6();  print colored('----------',"$boldblack on_$bgcblack"); print colored('/\\ \\',"$boldblack on_$bgcwhite"); print colored('x\/#',"$boldyellow on_$bgcred"); print colored('/ /\\',"$boldblack on_$bgcwhite"); print colored('----------',"$boldblack on_$bgcblack");print colored('|                           |',"$boldred on_$bgcred");print"\n";
	ruskieleft7();  print colored('---',"$boldblack on_$bgcblack"); print colored('/ ____   \\______/   ____ \\',"$boldblack on_$bgcwhite"); print colored('---',"$boldblack on_$bgcblack");print colored('|',"$boldred on_$bgcred");print colored('  Win: 25 COINS            ',"$boldyellow on_$bgcred");print colored('|',"$boldred on_$bgcred");print"\n";
	ruskieleft8();  print colored('--',"$boldblack on_$bgcblack"); print colored('| /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\    ||||    /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\ |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|',"$boldred on_$bgcred");print colored(' Lose: YOUR LIFE           ',"$boldyellow on_$bgcred");print colored('|',"$boldred on_$bgcred");print"\n";
	ruskieleft9();  print colored('--',"$boldblack on_$bgcblack"); print colored('| ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ||||    ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored(' |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|                           |',"$boldred on_$bgcred");print"\n";
	ruskieleft10(); print colored('--',"$boldblack on_$bgcblack"); print colored('| \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/    ||||    \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|                           |',"$boldred on_$bgcred");print"\n";
	ruskieleft11(); print colored('---',"$boldblack on_$bgcblack"); print colored('\\          ||||          /',"$boldblack on_$bgcwhite"); print colored('---',"$boldblack on_$bgcblack");print colored('|                           |',"$boldred on_$bgcred");print"\n";
	ruskieleft12(); print colored('----',"$boldblack on_$bgcblack"); print colored('>         ||||         <',"$boldblack on_$bgcwhite"); print colored('----',"$boldblack on_$bgcblack");print colored('|      ',"$boldred on_$bgcred"); ruskiebutton1(); print colored('      |',"$boldred on_$bgcred");print"\n";
	ruskieleft13(); print colored('---',"$boldblack on_$bgcblack"); print colored('/ ____     \__/     ____ \\',"$boldblack on_$bgcwhite");print colored('---',"$boldblack on_$bgcblack"); print colored('|      ',"$boldred on_$bgcred"); ruskiebutton2(); print colored('      |',"$boldred on_$bgcred");print"\n";
	ruskieleft14(); print colored('--',"$boldblack on_$bgcblack"); print colored('| /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\            /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\ |',"$boldblack on_$bgcwhite"); ;print colored('--',"$boldblack on_$bgcblack");print colored('|      ',"$boldred on_$bgcred"); ruskiebutton6(); print colored('      |',"$boldred on_$bgcred");print"\n";
	ruskieleft15(); print colored('--',"$boldblack on_$bgcblack"); print colored('| ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored('            ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored(' |',"$boldblack on_$bgcwhite"); print colored('--',"$boldblack on_$bgcblack");print colored('|      ',"$boldred on_$bgcred"); ruskiebutton4(); print colored('      |',"$boldred on_$bgcred");print"\n";
	ruskieleft16(); print colored('--',"$boldblack on_$bgcblack"); print colored('| \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/    ____    \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ |',"$boldblack on_$bgcwhite");print colored('--',"$boldblack on_$bgcblack");print colored('|      ',"$boldred on_$bgcred"); ruskiebutton6(); print colored('      |',"$boldred on_$bgcred");  print"\n";
	ruskieleft17(); print colored('---',"$boldblack on_$bgcblack"); print colored('\\______   /',"$boldblack on_$bgcwhite"); print colored('    ',"$yellow on_$bgcblack"); print colored('\\   ______/',"$boldblack on_$bgcwhite");print colored('---',"$boldblack on_$bgcblack");  print colored('|      ',"$boldred on_$bgcred"); ruskiebutton6(); print colored('      |',"$boldred on_$bgcred");print"\n";
	ruskieleft18(); print colored('----------',"$boldblack on_$bgcblack"); print colored('\\  ',"$boldblack on_$bgcwhite"); print colored('|',"$boldblack on_$bgcblack"); print colored('    ',"$yellow on_$bgcblack"); print colored('|',"$boldblack on_$bgcblack"); print colored('  /',"$boldblack on_$bgcwhite"); print colored('----------',"$boldblack on_$bgcblack");print colored('|      ',"$boldred on_$bgcred"); ruskiebutton7(); print colored('      |',"$boldred on_$bgcred"); print"\n";
	ruskieleft19(); print colored('-----------',"$boldblack on_$bgcblack"); print colored('\\ \\',"$boldblack on_$bgcwhite"); print colored('____',"$boldblack on_$bgcblack"); print colored('/ /',"$boldblack on_$bgcwhite");print colored('-----------',"$boldblack on_$bgcblack");print colored('|      ',"$boldred on_$bgcred"); ruskiebutton8(); print colored('      |',"$boldred on_$bgcred");    print"\n";
	ruskieleft20(); print colored('------------',"$boldblack on_$bgcblack"); print colored('\\______/',"$boldblack on_$bgcwhite"); print colored('------------',"$boldblack on_$bgcblack");  print colored('|                           |',"$boldred on_$bgcred"); print"\n"; 
	ruskieleft21(); print colored('--------------------------------',"$boldblack on_$bgcblack"); print colored('|                           |',"$boldred on_$bgcred");print"\n";
	}
}

sub ruskiebottom {
	if ($ruskieold == 1) {
	print colored('|            5555 \\--------------------------------/                           |',"$boldmagenta on_$bgcmagenta"); print"\n";
	print colored('|           5555                                           ',"$boldmagenta on_$bgcmagenta"); print colored('                    |',"$boldblack on_$bgcblack"); print"\n";
	print colored('| 555555555555          ',"$boldmagenta on_$bgcmagenta"); print colored('<> RUSSIAN ROULETTE <>             ',"$boldyellow on_$bgcmagenta"); print colored('   FUNDS ',"$boldblack on_$bgcblack"); ruskietotal(); print colored(' |',"$boldblack on_$bgcblack"); print"\n";
	print colored('|                                                          ',"$boldmagenta on_$bgcmagenta"); print colored('                    |',"$boldblack on_$bgcblack"); print"\n";
	print colored('\__________________________________________________________',"$boldmagenta on_$bgcmagenta"); print colored('____________________/',"$boldblack on_$bgcblack"); print"\n";
	} else {
	print colored('|',"$boldred on_$bgcred"); print colored('  *** ',"$boldyellow on_$bgcred"); print colored('      5555 \\--------------------------------/                           |',"$boldred on_$bgcred"); print"\n";
	print colored('|',"$boldred on_$bgcred"); print colored(' *   *',"$boldyellow on_$bgcred"); print colored('     5555                                           ',"$boldred on_$bgcred"); print colored('                    |',"$boldblack on_$bgcblack"); print"\n";
	print colored('| 555555555555          ',"$boldred on_$bgcred"); print colored('   RUSSIAN ROULETTE                ',"$boldred on_$bgcred"); print colored('   FUNDS ',"$boldblack on_$bgcblack"); ruskietotal(); print colored(' |',"$boldblack on_$bgcblack"); print"\n";
	print colored('|                                                          ',"$boldred on_$bgcred"); print colored('                    |',"$boldblack on_$bgcblack"); print"\n";
	print colored('\__________________________________________________________',"$boldred on_$bgcred"); print colored('____________________/',"$boldblack on_$bgcblack"); print"\n";
	}
}

sub ruskiebutton1 { print colored('IIIIIIIIIIIIIII',"$boldblack on_$bgcwhite"); }
sub ruskiebutton2 { print colored('I',"$boldblack on_$bgcwhite"); print colored('| . . . . . |',"$boldblack on_$bgcblack"); print colored('I',"$boldblack on_$bgcwhite"); }
sub ruskiebutton4 { print colored('I',"$boldblack on_$bgcwhite"); print colored('| . PRESS . |',"$boldblack on_$bgcblack"); print colored('I',"$boldblack on_$bgcwhite"); }
sub ruskiebutton6 { print colored('I',"$boldblack on_$bgcwhite"); print colored('| . . . . . |',"$boldblack on_$bgcblack"); print colored('I',"$boldblack on_$bgcwhite"); }
sub ruskiebutton7 { print colored('I',"$boldblack on_$bgcwhite"); print colored('|___________|',"$boldblack on_$bgcblack"); print colored('I',"$boldblack on_$bgcwhite"); }
sub ruskiebutton8 { print colored('IIIIIIIIIIIIIII',"$boldblack on_$bgcwhite"); }

sub ruskieleft1  { print colored('|                 |',"$boldred on_$bgcred"); }
sub ruskieleft2  { print colored('|     2222222     |',"$boldred on_$bgcred"); }
sub ruskieleft3  { print colored('|  2222222222222  |',"$boldred on_$bgcred"); }
sub ruskieleft4  { print colored('| 222         222 |',"$boldred on_$bgcred"); }
sub ruskieleft5  { print colored('|             222 |',"$boldred on_$bgcred"); }
sub ruskieleft6  { print colored('|           2222  |',"$boldred on_$bgcred"); }
sub ruskieleft7  { print colored('|         2222    |',"$boldred on_$bgcred"); } 
sub ruskieleft8  { print colored('|       2222      |',"$boldred on_$bgcred"); }
sub ruskieleft9  { print colored('|     2222        |',"$boldred on_$bgcred"); }
sub ruskieleft10 { print colored('|   2222          |',"$boldred on_$bgcred"); } 
sub ruskieleft11 { print colored('| 222222222222222 |',"$boldred on_$bgcred"); }
sub ruskieleft12 { print colored('|                 |',"$boldred on_$bgcred"); }
sub ruskieleft13 { print colored('| 555555555555555 |',"$boldred on_$bgcred"); }
sub ruskieleft14 { print colored('| 555555555555555 |',"$boldred on_$bgcred"); }
sub ruskieleft15 { print colored('| 5555            |',"$boldred on_$bgcred"); }
sub ruskieleft16 { print colored('| 5555            |',"$boldred on_$bgcred"); }
sub ruskieleft17 { print colored('|  5555           |',"$boldred on_$bgcred"); }
sub ruskieleft18 { print colored('|    55555555     |',"$boldred on_$bgcred"); }
sub ruskieleft19 { print colored('|      555555555  |',"$boldred on_$bgcred"); }
sub ruskieleft20 { print colored('|',"$boldred on_$bgcred"); print colored('   *  ',"$boldyellow on_$bgcred"); print colored('      5555 |',"$boldred on_$bgcred"); }
sub ruskieleft21 { print colored('|',"$boldred on_$bgcred"); print colored(' *****',"$boldyellow on_$bgcred"); print colored('      5555 |',"$boldred on_$bgcred"); }

sub ruskiemain {
	if ($ruskierand == 0) {
		ruskie1rlv();
	} elsif ($ruskierand == 1) {
		ruskie2rlv();
	} elsif ($ruskierand == 2) {
		ruskie3rlv();
	} elsif ($ruskierand == 3) {
		ruskie4rlv();
	} elsif ($ruskierand == 4) {
		ruskie5rlv();
	} elsif ($ruskierand == 5) {
		if ($ruskie2rand == 42) {
			ruskie0rlv();
		} else {
			ruskie6rlv();
			ruskiebottom();
			if ($soundfx == 1) {
				print"\a";
			}	
			$ruskiedie = <STDIN>;
			chomp($ruskiedie);
			ruskiedeath();
		}
	} else {
		ruskie0rlv();
	}
}

sub ruskiepay {
	if ($money >= 10000000000000000000000000) {
		$ruskiemulti = $money * 0.01;
	} elsif ($money >= 1000000000000000000000000) {
		$ruskiemulti = 10000000000000000000000;
	} elsif ($money >= 100000000000000000000000) {
		$ruskiemulti = 1000000000000000000000;
	} elsif ($money >= 10000000000000000000000) {
		$ruskiemulti = 100000000000000000000;
	} elsif ($money >= 1000000000000000000000) {
		$ruskiemulti = 10000000000000000000;
	} elsif ($money >= 100000000000000000000) {
		$ruskiemulti = 1000000000000000000;
	} elsif ($money >= 10000000000000000000) {
		$ruskiemulti = 100000000000000000;
	} elsif ($money >= 1000000000000000000) {
		$ruskiemulti = 10000000000000000;
	} elsif ($money >= 100000000000000000) {
		$ruskiemulti = 1000000000000000;
	} elsif ($money >= 10000000000000000) {
		$ruskiemulti = 100000000000000;
	} elsif ($money >= 1000000000000000) {
		$ruskiemulti = 10000000000000;
	} elsif ($money >= 100000000000000) {
		$ruskiemulti = 1000000000000;
	} elsif ($money >= 10000000000000) {
		$ruskiemulti = 100000000000;
	} elsif ($money >= 1000000000000) {
		$ruskiemulti = 10000000000;
	} elsif ($money >= 100000000000) {
		$ruskiemulti = 1000000000;
	} elsif ($money >= 10000000000) {
		$ruskiemulti = 100000000;
	} elsif ($money >= 1000000000) {
		$ruskiemulti = 10000000;
	} elsif ($money >= 100000000) {
		$ruskiemulti = 1000000;
	} elsif ($money >= 10000000) {
		$ruskiemulti = 100000;
	} elsif ($money >= 1000000) {
		$ruskiemulti = 10000;
	} elsif ($money >= 100000) {
		$ruskiemulti = 1000;
	} elsif ($money >= 10000) {
		$ruskiemulti = 100;
	} elsif ($money >= 1000) {
		$ruskiemulti = 10;
	} else {
		$ruskiemulti = 1;
	}
	
	if ($ruskierand == 0) {
		$ruskiemoney = 25 * $ruskiemulti;
		$rrstwin = $rrstwin + 1;
	} elsif ($ruskierand == 1) {
		$ruskiemoney = 25 * $ruskiemulti;
		$rrstwin = $rrstwin + 1;
	} elsif ($ruskierand == 2) {
		$ruskiemoney = 25 * $ruskiemulti;
		$rrstwin = $rrstwin + 1;
	} elsif ($ruskierand == 3) {
		$ruskiemoney = 25 * $ruskiemulti;
		$rrstwin = $rrstwin + 1;
	} elsif ($ruskierand == 4) {
		$ruskiemoney = 25 * $ruskiemulti;
		$rrstwin = $rrstwin + 1;
	} elsif ($ruskierand == 5) {
		if ($ruskie2rand == 42) {
			$ruskiemoney = 250 * $ruskiemulti;
			$rrstwin = $rrstwin + 1;
		} else {
			$ruskiemoney = 0;
			$rrstlose = $rrstlose + 1;
			$rrstmc2 = 'life';
		}
	} else {
		$ruskiemoney = 25;
		$rrstwin = $rrstwin + 1;
	}
	
	$money = $money + $ruskiemoney;
	$rrstmc = $rrstmc + $ruskiemoney;
	$ruskiemoney = 0;
}

sub ruskiestart {
	$ruskiestartinfo = <STDIN>;
	chomp($ruskiestartinfo);

	if (($ruskiestartinfo eq 'p') or ($ruskiestartinfo eq 'P') or ($ruskiestartinfo eq 'a') or ($ruskiestartinfo eq 'A')) {
		$ruskiestspin = $ruskiestspin + 1;
		ruskieroll();
	} elsif (($ruskiestartinfo eq 'exit') or ($ruskiestartinfo eq 'EXIT') or ($ruskiestartinfo eq 'quit') or ($ruskiestartinfo eq 'QUIT')) {
		exitgame();
	} elsif (($ruskiestartinfo eq 'c') or ($ruskiestartinfo eq 'C')) {
		newlines();
		if (($music == 1) and ($ruskieold == 0)) {
			killmusic();
			$music = 1;
			beginmusic();
		} else {
			#NOTHING!
		}
		return;			
	} else {
		ruskieroll2();
	}
}

sub ruskiespin {
	$ruskierand = int(rand(6));
	$ruskie2rand = int(rand(80));
}

sub ruskieroll2 {
	newlines();
	ruskietop();
	ruskiemain();
	ruskiebottom();
	ruskiestart();
}


sub ruskieroll {
	newlines();
	
	if ($animate == 1) {
		ruskiespin();
		$ruskie2rand = 42;
		ruskietop();
		ruskiemain();
		ruskiebottom();
		tinypause();
		newlines();
	
		ruskiespin();
		$ruskie2rand = 42;
		ruskietop();
		ruskiemain();
		ruskiebottom();
		tinypause();
		newlines();
		
		ruskiespin();
		$ruskie2rand = 42;
		ruskietop();
		ruskiemain();
		ruskiebottom();
		tinypause();
		newlines();
	
		ruskiespin();
		$ruskie2rand = 42;
		ruskietop();
		ruskiemain();
		ruskiebottom();
		tinypause();
		newlines();
	}
	
	ruskiespin();
	ruskietop();
	ruskiemain();
	ruskiepay();
	ruskiebottom();
	ptracker();
	ruskiestart();
}

sub ruskietotal {
	sep;
	if ($money > 9999999999) {
	print colored(sprintf("%.4e", $money),"$boldgreen on_$bgcgreen");
	} elsif ($money >= 1000000000) {
	print colored("$money","$boldgreen on_$bgcgreen");
	} elsif ($money >= 100000000) {
	print colored(" $money","$boldgreen on_$bgcgreen");
	} elsif ($money >= 10000000) {
	print colored("  $money","$boldgreen on_$bgcgreen");
	} elsif ($money >= 1000000) {
	print colored("   $money","$boldgreen on_$bgcgreen");
	} elsif ($money >= 100000) {
	print colored("    $money","$boldgreen on_$bgcgreen");
	} elsif ($money >= 10000) {
	print colored("     $money","$boldgreen on_$bgcgreen");
	} elsif ($money >= 1000) {
	print colored("      $money","$boldgreen on_$bgcgreen");
	} elsif ($money >= 100) {
	print colored("       $money","$boldgreen on_$bgcgreen");
	} elsif ($money >= 10) {
	print colored("        $money","$boldgreen on_$bgcgreen");
	} elsif ($money >= 1) {
	print colored("         $money","$boldgreen on_$bgcgreen");
	} else {
	print colored("         $money","$boldgreen on_$bgcgreen");
	}
	sep;
}

sub ruskiedeath {
	newlines();
	killmusic();
	if ($allowsave == 1) {
		zerosavefile();
	}
	newlines();
	$titlecolor = "$blue";
	print colored('                                                                                ',"$boldyellow on_$bgcred"); print"\n"; 
	print colored('                                                                                ',"$boldyellow on_$bgcred"); print"\n"; 
	print colored('                                                                                ',"$boldyellow on_$bgcred"); print"\n"; 
	print colored("$namedeath","$boldyellow on_$bgcred"); print"\n"; 
	print colored("                               GENERAL PUBLIC                                   ","$boldyellow on_$bgcred"); print"\n"; 
	print colored("                                                                                ","$boldyellow on_$bgcred"); print"\n"; 
	print colored('                           SSSSSS     IIIIIIIIIII                               ',"$titlecolor on_$bgcred"); print"\n"; 
	print colored('                         SSSSSSSSSS  IIIIIIIIIIIII                              ',"bold $titlecolor on_$bgcred"); print"\n"; 
	print colored('                        SSSS    SSSS     IIIII                                  ',"$titlecolor on_$bgcred"); print"\n"; 
	print colored('                  A     SSS              IIIII      NNNN     NNNNN              ',"bold $titlecolor on_$bgcred"); print"\n"; 
	print colored('                 AAA    SSSS             IIIII      NNNNN     NNN               ',"$titlecolor on_$bgcred"); print"\n"; 
	print colored('                AAAAA    SSSSSSSSS       IIIII      NNNNNN    NNN               ',"bold $titlecolor on_$bgcred"); print"\n"; 
	print colored('               AAAAAAA    SSSSSSSSS      IIIII      NNNNNNN   NNN               ',"$titlecolor on_$bgcred"); print"\n";        
	print colored('    CCCCCC    AAAA AAAA         SSSS     IIIII      NNN NNNN  NNN     OOOOOOO   ',"bold $titlecolor on_$bgcred"); print"\n"; 
	print colored('  CCCCCCCCCC  AAA   AAA          SSS     IIIII      NNN  NNNN NNN   OOOOOOOOOOO ',"$titlecolor on_$bgcred"); print"\n"; 
	print colored(' CCCC    CCCC AAAAAAAAA SSSS    SSSS     IIIII      NNN   NNNNNNN  OOOOO   OOOOO',"bold $titlecolor on_$bgcred"); print"\n"; 
	print colored(' CCC          AAA   AAA  SSSSSSSSSS  IIIIIIIIIIIII  NNN    NNNNNN  OOOO     OOOO',"$titlecolor on_$bgcred"); print"\n"; 
	print colored(' CCC          AAA   AAA    SSSSSS     IIIIIIIIIII   NNN     NNNNN  OOOO     OOOO',"bold $titlecolor on_$bgcred"); print"\n"; 
	print colored(' CCCC    CCCC AAA   AAA                            NNNNN     NNNN  OOOOO   OOOOO',"$titlecolor on_$bgcred"); print"\n"; 
	print colored('  CCCCCCCCCC                                                        OOOOOOOOOOO ',"bold $titlecolor on_$bgcred"); print"\n"; 
	print colored('    CCCCCC                                                            OOOOOOO   ',"$titlecolor on_$bgcred"); print"\n"; 
	print colored('                                                                                ',"$boldyellow on_$bgcred"); print"\n"; 
	print colored("                                                                version $version   ","$boldblack on_$bgcred"); print"\n"; 

	if ($moneyexp >= 10000000000) {
		print colored(" Expended Cash: $moneyexp                                                     ","$white on_$bgcred"); print"\n"; 
	} elsif  ($moneyexp >= 1000000000) {
		print colored(" Expended Cash: $moneyexp                                                      ","$white on_$bgcred"); print"\n"; 
	} elsif  ($moneyexp >= 100000000) {
		print colored(" Expended Cash: $moneyexp                                                       ","$white on_$bgcred"); print"\n"; 
	} elsif  ($moneyexp >= 10000000) {
		print colored(" Expended Cash: $moneyexp                                                        ","$white on_$bgcred"); print"\n"; 
	} elsif  ($moneyexp >= 1000000) {
		print colored(" Expended Cash: $moneyexp                                                         ","$white on_$bgcred"); print"\n"; 
	} elsif  ($moneyexp >= 100000) {
		print colored(" Expended Cash: $moneyexp                                                          ","$white on_$bgcred"); print"\n"; 
	} elsif  ($moneyexp >= 10000) {
		print colored(" Expended Cash: $moneyexp                                                           ","$white on_$bgcred"); print"\n"; 
	} elsif  ($moneyexp >= 1000) {
		print colored(" Expended Cash: $moneyexp                                                            ","$white on_$bgcred"); print"\n"; 
	} elsif  ($moneyexp >= 100) {
		print colored(" Expended Cash: $moneyexp                                                             ","$white on_$bgcred"); print"\n"; 
	} elsif  ($moneyexp >= 10) {
		print colored(" Expended Cash: $moneyexp                                                              ","$white on_$bgcred"); print"\n"; 
	} elsif  ($moneyexp >= 0) {
		print colored(" Expended Cash: $moneyexp                                                               ","$white on_$bgcred"); print"\n"; 
	} else {
		print colored(" Expended Cash: $moneyexp                                                               ","$white on_$bgcred"); print"\n"; 
	}

	if ($money >= 10000000000) {
		print colored(" Aquired Wealth: $money                                                    ","$white on_$bgcred"); print"\n"; 
	} elsif  ($money >= 1000000000) {
		print colored(" Aquired Wealth: $money                                                     ","$white on_$bgcred"); print"\n"; 
	} elsif  ($money >= 100000000) {
		print colored(" Aquired Wealth: $money                                                      ","$white on_$bgcred"); print"\n"; 
	} elsif  ($money >= 10000000) {
		print colored(" Aquired Wealth: $money                                                       ","$white on_$bgcred"); print"\n"; 
	} elsif  ($moneyexp >= 1000000) {
		print colored(" Aquired Wealth: $money                                                        ","$white on_$bgcred"); print"\n"; 
	} elsif  ($money >= 100000) {
		print colored(" Aquired Wealth: $money                                                         ","$white on_$bgcred"); print"\n"; 
	} elsif  ($money >= 10000) {
		print colored(" Aquired Wealth: $money                                                          ","$white on_$bgcred"); print"\n"; 
	} elsif  ($money >= 1000) {
		print colored(" Aquired Wealth: $money                                                           ","$white on_$bgcred"); print"\n"; 
	} elsif  ($money >= 100) {
		print colored(" Aquired Wealth: $money                                                            ","$white on_$bgcred"); print"\n"; 
	} elsif  ($money >= 10) {
		print colored(" Aquired Wealth: $money                                                             ","$white on_$bgcred"); print"\n"; 
	} elsif  ($money >= 0) {
		print colored(" Aquired Wealth: $money                                                              ","$white on_$bgcred"); print"\n"; 
	} else {
		print colored(" Aquired Wealth: $money                                                              ","$white on_$bgcred"); print"\n"; 
	}

	print colored('                                                                                ',"$boldyellow on_$bgcred"); print"\n"; 
	print colored('                                                                                ',"$boldyellow on_$bgcred"); print"\n"; 
	print colored('                                                                                ',"$boldyellow on_$bgcred"); print"\n"; 
	print colored('                                                                                ',"$boldyellow on_$bgcred"); print"\n"; 	
	sleep(2);
	exit();
}



################################################################################################################################
## GENRE: Roulette
## NAME: Monte Carlo Roulette
## AUTHOR: MikeeUSA

sub lvrmainspin1 {
	lvrreset();
	lvrcolorsg();
	
	if ($animate == 1) {
		$lvrreelspin = 2;
		
		lvrstdcomp();
		lvrspin();
		lvrwheel();
		lvrprintmain();
		p4pause();
		newlines();
		
		lvrstdcomp();
		lvrspin();
		lvrwheel();
		lvrprintmain();
		p4pause();
		newlines();
		
		lvrstdcomp();
		lvrspin();
		lvrwheel();
		lvrprintmain();
		p4pause();
		newlines();
		
		lvrstdcomp();
		lvrspin();
		lvrwheel();
		lvrprintmain();
		p4pause();
		newlines();
		
		lvrstdcomp();
		lvrspin();
		lvrwheel();
		lvrprintmain();
		p4pause();
		newlines();
		
		lvrstdcomp();
		lvrspin();
		lvrwheel();
		lvrprintmain();
		p4pause();
		newlines();
		
		lvrstdcomp();
		lvrspin();
		lvrwheel();
		lvrprintmain();
		p4pause();
		newlines();
		
		lvrstdcomp();
		lvrspin();
		lvrwheel();
		lvrprintmain();
		p4pause();
		newlines();
		
		
		
		lvrstdcomp();
		lvrspin();
		lvrwheel();
		lvrprintmain();
		p7pause();
		newlines();
		
		lvrstdcomp();
		lvrspin();
		lvrwheel();
		lvrprintmain();
		p7pause();
		newlines();
		
		lvrstdcomp();
		lvrspin();
		lvrwheel();
		lvrprintmain();
		p7pause();
		newlines();
		$lvrreelspin = 1;
		lvrstdcomp();
		lvrspin();
		lvrwheel();
		lvrprintmain();
		p7pause();
		newlines();
		
		lvrstdcomp();
		lvrspin();
		lvrwheel();
		lvrprintmain();
		p7pause();
		newlines();
		
		lvrstdcomp();
		lvrspin();
		lvrwheel();
		lvrprintmain();
		p7pause();
		newlines();
		
		lvrstdcomp();
		lvrspin();
		lvrwheel();
		lvrprintmain();
		p7pause();
		newlines();
		
		
		
		lvrstdcomp();
		lvrspin();
		lvrwheel();
		lvrprintmain();
		tinypause();
		newlines();
		
		lvrstdcomp();
		lvrspin();
		lvrwheel();
		lvrprintmain();
		tinypause();
		newlines();
		
		lvrstdcomp();
		lvrspin();
		lvrwheel();
		lvrprintmain();
		tinypause();
		newlines();
		
		
				
		lvrstdcomp();
		lvrspin();
		lvrwheel();
		lvrprintmain();
		smallpause();
		newlines();
		
		
	}
	$lvrreelspin = 0;
	lvrstdcomp();
	lvrspin();
	lvrwheel();
	lvraddmoney();
	if ((($lvrstart2 eq 'T1') or ($lvrstart2 eq 'T2') or ($lvrstart2 eq 'T3')
	or ($lvrstart2 eq 'F1') or ($lvrstart2 eq 'F2') or ($lvrstart2 eq 'F3') or ($lvrstart2 eq 'F4')) 
	and (($lvrwinnbr == 37))) {
		if (($lvrsetup == 0) and ($lvrimprison != 0)) {
			lvrnbrreset();
			$lvrstart2 = ' ';
		}
	}
	lvrprintmain();
	ptracker();
	lvrstdin1();
}

sub lvrmainspin2 {
	lvrreset();
	lvrcolorsg();
	lvrstdcomp();
	lvrwheel();
	lvrprintmain();
	lvrstdin1();
}

sub lvrnbrspin3 {
	lvrreset();
	lvrcolorsg();
	lvrnbrcomp();
	lvrwheel();
	lvrprintmain();
	$lvrstart2 = <STDIN>;
	chomp($lvrstart2);
		lvrnbrreset();
		if ($lvrstart2 eq '0') {
			$lvrb0p = 1;
		} elsif ($lvrstart2 eq '1') {
			$lvrb1p = 1;
		} elsif ($lvrstart2 eq '2') {
			$lvrb2p = 1;
		} elsif ($lvrstart2 eq '3') {
			$lvrb3p = 1;
		} elsif ($lvrstart2 eq '4') {
			$lvrb4p = 1;
		} elsif ($lvrstart2 eq '5') {
			$lvrb5p = 1;
		} elsif ($lvrstart2 eq '6') {
			$lvrb6p = 1;
		} elsif ($lvrstart2 eq '7') {
			$lvrb7p = 1;
		} elsif ($lvrstart2 eq '8') {
			$lvrb8p = 1;
		} elsif ($lvrstart2 eq '9') {
			$lvrb9p = 1;
		} elsif ($lvrstart2 eq '10') {
			$lvrb10p = 1;
		} elsif ($lvrstart2 eq '11') {
			$lvrb11p = 1;
		} elsif ($lvrstart2 eq '12') {
			$lvrb12p = 1;
		} elsif ($lvrstart2 eq '13') {
			$lvrb13p = 1;
		} elsif ($lvrstart2 eq '14') {
			$lvrb14p = 1;
		} elsif ($lvrstart2 eq '15') {
			$lvrb15p = 1;
		} elsif ($lvrstart2 eq '16') {
			$lvrb16p = 1;
		} elsif ($lvrstart2 eq '17') {
			$lvrb17p = 1;
		} elsif ($lvrstart2 eq '18') {
			$lvrb18p = 1;
		} elsif ($lvrstart2 eq '19') {
			$lvrb19p = 1;
		} elsif ($lvrstart2 eq '20') {
			$lvrb20p = 1;
		} elsif ($lvrstart2 eq '21') {
			$lvrb21p = 1;
		} elsif ($lvrstart2 eq '22') {
			$lvrb22p = 1;
		} elsif ($lvrstart2 eq '23') {
			$lvrb23p = 1;
		} elsif ($lvrstart2 eq '24') {
			$lvrb24p = 1;
		} elsif ($lvrstart2 eq '25') {
			$lvrb25p = 1;
		} elsif ($lvrstart2 eq '26') {
			$lvrb26p = 1;
		} elsif ($lvrstart2 eq '27') {
			$lvrb27p = 1;
		} elsif ($lvrstart2 eq '28') {
			$lvrb28p = 1;
		} elsif ($lvrstart2 eq '29') {
			$lvrb29p = 1;
		} elsif ($lvrstart2 eq '30') {
			$lvrb30p = 1;
		} elsif ($lvrstart2 eq '31') {
			$lvrb31p = 1;
		} elsif ($lvrstart2 eq '32') {
			$lvrb32p = 1;
		} elsif ($lvrstart2 eq '33') {
			$lvrb33p = 1;
		} elsif ($lvrstart2 eq '34') {
			$lvrb34p = 1;
		} elsif ($lvrstart2 eq '35') {
			$lvrb35p = 1;
		} elsif ($lvrstart2 eq '36') {
			$lvrb36p = 1;
		} elsif (($lvrstart2 eq 'even') or ($lvrstart2 eq 'EVEN')) {
			$lvrstart2 = 'EVEN';
			$lvrb2p = 1;	
			$lvrb4p = 1;
			$lvrb6p = 1;
			$lvrb8p = 1;	
			$lvrb10p = 1;
			$lvrb12p = 1;	
			$lvrb14p = 1;
			$lvrb16p = 1;
			$lvrb18p = 1;	
			$lvrb20p = 1;	
			$lvrb22p = 1;	
			$lvrb24p = 1;
			$lvrb26p = 1;
			$lvrb28p = 1;	
			$lvrb30p = 1;
			$lvrb32p = 1;	
			$lvrb34p = 1;
			$lvrb36p = 1;
		} elsif (($lvrstart2 eq 'odd') or ($lvrstart2 eq 'ODD')) {
			$lvrstart2 = 'ODD';
			$lvrb1p = 1;	
			$lvrb3p = 1;
			$lvrb5p = 1;
			$lvrb7p = 1;	
			$lvrb9p = 1;
			$lvrb11p = 1;	
			$lvrb13p = 1;
			$lvrb15p = 1;
			$lvrb17p = 1;	
			$lvrb19p = 1;	
			$lvrb21p = 1;	
			$lvrb23p = 1;
			$lvrb25p = 1;
			$lvrb27p = 1;	
			$lvrb29p = 1;
			$lvrb31p = 1;	
			$lvrb33p = 1;
			$lvrb35p = 1;
		} elsif (($lvrstart2 eq 'lower18') or ($lvrstart2 eq 'LOWER18')) {
			$lvrstart2 = 'LOWER18';
			$lvrb1p = 1;	
			$lvrb2p = 1;
			$lvrb3p = 1;
			$lvrb4p = 1;	
			$lvrb5p = 1;
			$lvrb6p = 1;	
			$lvrb7p = 1;
			$lvrb8p = 1;
			$lvrb9p = 1;	
			$lvrb10p = 1;	
			$lvrb11p = 1;	
			$lvrb12p = 1;
			$lvrb13p = 1;
			$lvrb14p = 1;	
			$lvrb15p = 1;
			$lvrb16p = 1;	
			$lvrb17p = 1;
			$lvrb18p = 1;
		} elsif (($lvrstart2 eq 'upper18') or ($lvrstart2 eq 'UPPER18')) {
			$lvrstart2 = 'UPPER18';
			$lvrb19p = 1;	
			$lvrb20p = 1;
			$lvrb21p = 1;
			$lvrb22p = 1;	
			$lvrb23p = 1;
			$lvrb24p = 1;	
			$lvrb25p = 1;
			$lvrb26p = 1;
			$lvrb27p = 1;	
			$lvrb28p = 1;	
			$lvrb29p = 1;	
			$lvrb30p = 1;
			$lvrb31p = 1;
			$lvrb32p = 1;	
			$lvrb33p = 1;
			$lvrb34p = 1;	
			$lvrb35p = 1;
			$lvrb36p = 1;	
		} elsif (($lvrstart2 eq 'c1') or ($lvrstart2 eq 'C1')) {
			$lvrstart2 = 'C1';
			$lvrb1p = 1;	
			$lvrb4p = 1;
			$lvrb7p = 1;
			$lvrb10p = 1;	
			$lvrb13p = 1;
			$lvrb16p = 1;	
			$lvrb19p = 1;
			$lvrb22p = 1;
			$lvrb25p = 1;	
			$lvrb28p = 1;	
			$lvrb31p = 1;	
			$lvrb34p = 1;
		} elsif (($lvrstart2 eq 'c2') or ($lvrstart2 eq 'C2')) {
			$lvrstart2 = 'C2';
			$lvrb2p = 1;	
			$lvrb5p = 1;
			$lvrb8p = 1;
			$lvrb11p = 1;	
			$lvrb14p = 1;
			$lvrb17p = 1;	
			$lvrb20p = 1;
			$lvrb23p = 1;
			$lvrb26p = 1;	
			$lvrb29p = 1;	
			$lvrb32p = 1;	
			$lvrb35p = 1;
		} elsif (($lvrstart2 eq 'c3') or ($lvrstart2 eq 'C3')) {
			$lvrstart2 = 'C3';
			$lvrb3p = 1;	
			$lvrb6p = 1;
			$lvrb9p = 1;
			$lvrb12p = 1;	
			$lvrb15p = 1;
			$lvrb18p = 1;	
			$lvrb21p = 1;
			$lvrb24p = 1;
			$lvrb27p = 1;	
			$lvrb30p = 1;	
			$lvrb33p = 1;	
			$lvrb36p = 1;
		} elsif (($lvrstart2 eq 'g1') or ($lvrstart2 eq 'G1')) {
			$lvrstart2 = 'G1';
			$lvrb1p = 1;	
			$lvrb2p = 1;
			$lvrb3p = 1;
			$lvrb4p = 1;	
			$lvrb5p = 1;
			$lvrb6p = 1;	
			$lvrb7p = 1;
			$lvrb8p = 1;
			$lvrb9p = 1;	
		} elsif (($lvrstart2 eq 'g2') or ($lvrstart2 eq 'G2')) {
			$lvrstart2 = 'G2';
			$lvrb10p = 1;	
			$lvrb11p = 1;
			$lvrb12p = 1;
			$lvrb13p = 1;	
			$lvrb14p = 1;
			$lvrb15p = 1;	
			$lvrb16p = 1;
			$lvrb17p = 1;
			$lvrb18p = 1;
		} elsif (($lvrstart2 eq 'g3') or ($lvrstart2 eq 'G3')) {
			$lvrstart2 = 'G3';
			$lvrb19p = 1;	
			$lvrb20p = 1;
			$lvrb21p = 1;
			$lvrb22p = 1;	
			$lvrb23p = 1;
			$lvrb24p = 1;	
			$lvrb25p = 1;
			$lvrb26p = 1;
			$lvrb27p = 1;
		} elsif (($lvrstart2 eq 'g4') or ($lvrstart2 eq 'G4')) {
			$lvrstart2 = 'G4';
			$lvrb28p = 1;	
			$lvrb29p = 1;
			$lvrb30p = 1;
			$lvrb31p = 1;	
			$lvrb32p = 1;
			$lvrb33p = 1;	
			$lvrb34p = 1;
			$lvrb35p = 1;
			$lvrb36p = 1;	
		} elsif (($lvrstart2 eq 'l1') or ($lvrstart2 eq 'L1')) {
			$lvrstart2 = 'L1';
			$lvrb1p = 1;	
			$lvrb2p = 1;
			$lvrb3p = 1;
		} elsif (($lvrstart2 eq 'l2') or ($lvrstart2 eq 'L2')) {
			$lvrstart2 = 'L2';
			$lvrb4p = 1;	
			$lvrb5p = 1;
			$lvrb6p = 1;
		} elsif (($lvrstart2 eq 'l3') or ($lvrstart2 eq 'L3')) {
			$lvrstart2 = 'L3';
			$lvrb7p = 1;	
			$lvrb8p = 1;
			$lvrb9p = 1;
		} elsif (($lvrstart2 eq 'l4') or ($lvrstart2 eq 'L4')) {
			$lvrstart2 = 'L4';
			$lvrb10p = 1;	
			$lvrb11p = 1;
			$lvrb12p = 1;
		} elsif (($lvrstart2 eq 'l5') or ($lvrstart2 eq 'L5')) {
			$lvrstart2 = 'L5';
			$lvrb13p = 1;	
			$lvrb14p = 1;
			$lvrb15p = 1;
		} elsif (($lvrstart2 eq 'l6') or ($lvrstart2 eq 'L6')) {
			$lvrstart2 = 'L6';
			$lvrb16p = 1;	
			$lvrb17p = 1;
			$lvrb18p = 1;
		} elsif (($lvrstart2 eq 'l7') or ($lvrstart2 eq 'L7')) {
			$lvrstart2 = 'L7';
			$lvrb19p = 1;	
			$lvrb20p = 1;
			$lvrb21p = 1;
		} elsif (($lvrstart2 eq 'l8') or ($lvrstart2 eq 'L8')) {
			$lvrstart2 = 'L8';
			$lvrb22p = 1;	
			$lvrb23p = 1;
			$lvrb24p = 1;
		} elsif (($lvrstart2 eq 'l9') or ($lvrstart2 eq 'L9')) {
			$lvrstart2 = 'L9';
			$lvrb25p = 1;	
			$lvrb26p = 1;
			$lvrb27p = 1;
		} elsif (($lvrstart2 eq 'l10') or ($lvrstart2 eq 'L10')) {
			$lvrstart2 = 'L10';
			$lvrb28p = 1;	
			$lvrb29p = 1;
			$lvrb30p = 1;
		} elsif (($lvrstart2 eq 'l11') or ($lvrstart2 eq 'L11')) {
			$lvrstart2 = 'L11';
			$lvrb31p = 1;	
			$lvrb32p = 1;
			$lvrb33p = 1;
		} elsif (($lvrstart2 eq 'l12') or ($lvrstart2 eq 'L12')) {
			$lvrstart2 = 'L12';
			$lvrb34p = 1;	
			$lvrb35p = 1;
			$lvrb36p = 1;
		} elsif (($lvrstart2 eq 'zc') or ($lvrstart2 eq 'ZC')) {
			$lvrstart2 = 'ZC';
			$lvrb0p = 1;
			$lvrb1p = 1;
			$lvrb2p = 1;
			$lvrb3p = 1;
		} elsif (($lvrstart2 eq 'f1') or ($lvrstart2 eq 'F1')) {
			if (($lvrsetup == 0) and ($lvrimprison != 0)) {
				$lvrstart2 = ' ';
			} else {
			$lvrstart2 = 'F1';
			$lvrb1p = 1;	
			$lvrb2p = 1;
			$lvrb3p = 1;
			$lvrb4p = 1;	
			$lvrb5p = 1;
			$lvrb6p = 1;	
			$lvrb7p = 1;
			$lvrb8p = 1;
			$lvrb9p = 1;	
			$lvrb10p = 1;	
			$lvrb11p = 1;	
			$lvrb12p = 1;
			$lvrb13p = 1;
			$lvrb14p = 1;	
			$lvrb15p = 1;
			$lvrb16p = 1;	
			$lvrb17p = 1;
			$lvrb18p = 1;
			$lvrb19p = 1;
			$lvrb20p = 1;
			$lvrb21p = 1;
			$lvrb22p = 1;
			$lvrb23p = 1;
			$lvrb24p = 1;
			$lvrb25p = 1;
			$lvrb26p = 1;
			$lvrb27p = 1;
			}
		} elsif (($lvrstart2 eq 'f2') or ($lvrstart2 eq 'F2')) {
			if (($lvrsetup == 0) and ($lvrimprison != 0)) {
				$lvrstart2 = ' ';
			} else {
			$lvrstart2 = 'F2';
			$lvrb10p = 1;	
			$lvrb11p = 1;	
			$lvrb12p = 1;
			$lvrb13p = 1;
			$lvrb14p = 1;	
			$lvrb15p = 1;
			$lvrb16p = 1;	
			$lvrb17p = 1;
			$lvrb18p = 1;
			$lvrb19p = 1;
			$lvrb20p = 1;
			$lvrb21p = 1;
			$lvrb22p = 1;
			$lvrb23p = 1;
			$lvrb24p = 1;
			$lvrb25p = 1;
			$lvrb26p = 1;
			$lvrb27p = 1;
			$lvrb28p = 1;
			$lvrb29p = 1;
			$lvrb30p = 1;
			$lvrb31p = 1;
			$lvrb32p = 1;
			$lvrb33p = 1;
			$lvrb34p = 1;
			$lvrb35p = 1;
			$lvrb36p = 1;
			}
		} elsif (($lvrstart2 eq 'f3') or ($lvrstart2 eq 'F3')) {
			if (($lvrsetup == 0) and ($lvrimprison != 0)) {
				$lvrstart2 = ' ';
			} else {
			$lvrstart2 = 'F3';
			$lvrb1p = 1;	
			$lvrb2p = 1;	
			$lvrb3p = 1;
			$lvrb4p = 1;
			$lvrb5p = 1;	
			$lvrb6p = 1;
			$lvrb7p = 1;	
			$lvrb8p = 1;
			$lvrb9p = 1;
			
			$lvrb19p = 1;
			$lvrb20p = 1;
			$lvrb21p = 1;
			$lvrb22p = 1;
			$lvrb23p = 1;
			$lvrb24p = 1;
			$lvrb25p = 1;
			$lvrb26p = 1;
			$lvrb27p = 1;
			$lvrb28p = 1;
			$lvrb29p = 1;
			$lvrb30p = 1;
			$lvrb31p = 1;
			$lvrb32p = 1;
			$lvrb33p = 1;
			$lvrb34p = 1;
			$lvrb35p = 1;
			$lvrb36p = 1;
			}
		} elsif (($lvrstart2 eq 'f4') or ($lvrstart2 eq 'F4')) {
			if (($lvrsetup == 0) and ($lvrimprison != 0)) {
				$lvrstart2 = ' ';
			} else {
			$lvrstart2 = 'F4';
			$lvrb1p = 1;	
			$lvrb2p = 1;	
			$lvrb3p = 1;
			$lvrb4p = 1;
			$lvrb5p = 1;	
			$lvrb6p = 1;
			$lvrb7p = 1;	
			$lvrb8p = 1;
			$lvrb9p = 1;
			$lvrb10p = 1;	
			$lvrb11p = 1;	
			$lvrb12p = 1;
			$lvrb13p = 1;
			$lvrb14p = 1;	
			$lvrb15p = 1;
			$lvrb16p = 1;	
			$lvrb17p = 1;
			$lvrb18p = 1;
			
			$lvrb28p = 1;
			$lvrb29p = 1;
			$lvrb30p = 1;
			$lvrb31p = 1;
			$lvrb32p = 1;
			$lvrb33p = 1;
			$lvrb34p = 1;
			$lvrb35p = 1;
			$lvrb36p = 1;
			}
		} elsif (($lvrstart2 eq 't1') or ($lvrstart2 eq 'T1')) {
			if (($lvrsetup == 0) and ($lvrimprison != 0)) {
				$lvrstart2 = ' ';
			} else {
			$lvrstart2 = 'T1';
			$lvrb1p = 1;	
			$lvrb2p = 1;
			$lvrb3p = 1;
			$lvrb4p = 1;	
			$lvrb5p = 1;
			$lvrb6p = 1;	
			$lvrb7p = 1;
			$lvrb8p = 1;
			$lvrb9p = 1;	
			$lvrb10p = 1;	
			$lvrb11p = 1;	
			$lvrb12p = 1;
			$lvrb13p = 1;
			$lvrb14p = 1;	
			$lvrb15p = 1;
			$lvrb16p = 1;	
			$lvrb17p = 1;
			$lvrb18p = 1;
			$lvrb19p = 1;
			$lvrb20p = 1;
			$lvrb21p = 1;
			$lvrb22p = 1;
			$lvrb23p = 1;
			$lvrb24p = 1;
			}
		} elsif (($lvrstart2 eq 't2') or ($lvrstart2 eq 'T2')) {
			if (($lvrsetup == 0) and ($lvrimprison != 0)) {
				$lvrstart2 = ' ';
			} else {
			$lvrstart2 = 'T2';	
			$lvrb7p = 1;
			$lvrb8p = 1;
			$lvrb9p = 1;	
			$lvrb10p = 1;	
			$lvrb11p = 1;	
			$lvrb12p = 1;
			$lvrb13p = 1;
			$lvrb14p = 1;	
			$lvrb15p = 1;
			$lvrb16p = 1;	
			$lvrb17p = 1;
			$lvrb18p = 1;
			$lvrb19p = 1;
			$lvrb20p = 1;
			$lvrb21p = 1;
			$lvrb22p = 1;
			$lvrb23p = 1;
			$lvrb24p = 1;
			$lvrb25p = 1;
			$lvrb26p = 1;
			$lvrb27p = 1;
			$lvrb28p = 1;
			$lvrb29p = 1;
			$lvrb30p = 1;
			}
		} elsif (($lvrstart2 eq 't3') or ($lvrstart2 eq 'T3')) {
			if (($lvrsetup == 0) and ($lvrimprison != 0)) {
				$lvrstart2 = ' ';
			} else {
			$lvrstart2 = 'T3';
			$lvrb13p = 1;
			$lvrb14p = 1;	
			$lvrb15p = 1;	
			$lvrb16p = 1;	
			$lvrb17p = 1;
			$lvrb18p = 1;
			$lvrb19p = 1;	
			$lvrb20p = 1;
			$lvrb21p = 1;	
			$lvrb22p = 1;
			$lvrb23p = 1;
			$lvrb24p = 1;
			$lvrb25p = 1;
			$lvrb26p = 1;
			$lvrb27p = 1;
			$lvrb28p = 1;
			$lvrb29p = 1;
			$lvrb30p = 1;
			$lvrb31p = 1;
			$lvrb32p = 1;
			$lvrb33p = 1;
			$lvrb34p = 1;
			$lvrb35p = 1;
			$lvrb36p = 1;
			}
		} elsif (($lvrsetup == 0) and (($lvrstart2 eq 'p2') or ($lvrstart2 eq 'P2'))) {
			$lvrstart2 = 'P2';
			$lvrb2p = 1;	
			$lvrb4p = 1;
			$lvrb8p = 1;
			$lvrb16p = 1;
			$lvrb32p = 1;
		} elsif (($lvrstart2 eq 'v') or ($lvrstart2 eq 'V')
		or ($lvrstart2 eq 'voisins') or ($lvrstart2 eq 'VOISINS')) {
			$lvrstart2 = 'VOISINS';
			$lvrbVOIp = 1;
			$lvrb0p = 1;
			$lvrb2p = 1;	
			$lvrb3p = 1;
			$lvrb4p = 1;
			$lvrb7p = 1;
			$lvrb12p = 1;
			$lvrb15p = 1;
			$lvrb18p = 1;
			$lvrb21p = 1;
			$lvrb19p = 1;
			$lvrb22p = 1;
			$lvrb25p = 1;
			$lvrb26p = 1;
			$lvrb28p = 1;
			$lvrb29p = 1;
			$lvrb32p = 1;
			$lvrb35p = 1;
		} elsif (($lvrstart2 eq 't') or ($lvrstart2 eq 'T')
		or ($lvrstart2 eq 'tiers') or ($lvrstart2 eq 'TIERS')) {
			$lvrstart2 = 'TIERS';
			$lvrbTIEp = 1;
			$lvrb5p = 1;
			$lvrb8p = 1;	
			$lvrb10p = 1;
			$lvrb11p = 1;
			$lvrb13p = 1;
			$lvrb16p = 1;
			$lvrb23p = 1;
			$lvrb24p = 1;	
			$lvrb27p = 1;
			$lvrb30p = 1;
			$lvrb33p = 1;
			$lvrb36p = 1;
		} elsif (($lvrstart2 eq 'o') or ($lvrstart2 eq 'O')
		or ($lvrstart2 eq 'orphelins') or ($lvrstart2 eq 'ORPHELINS') 
		or ($lvrstart2 eq 'orphans') or ($lvrstart2 eq 'ORPHANS')) {
			$lvrstart2 = 'ORPHELINS';
			$lvrbORPp = 1;
			$lvrb1p = 1;
			$lvrb6p = 1;	
			$lvrb9p = 1;
			$lvrb14p = 1;
			$lvrb17p = 1;
			$lvrb20p = 1;
			$lvrb31p = 1;
			$lvrb34p = 1;																																	
		} elsif ((($lvrstart2 eq 'red') and ($lvrsetup == 0) and ($lvrfuturecarlo != 1)) or (($lvrstart2 eq 'RED') and ($lvrsetup == 0) and ($lvrfuturecarlo != 1))) {
			$lvrstart2 = 'RED';
			$lvrbRp = 1;
		} elsif ((($lvrstart2 eq 'magenta') and ($lvrsetup == 0) and ($lvrfuturecarlo == 1)) or (($lvrstart2 eq 'MAGENTA') and ($lvrsetup == 0) and ($lvrfuturecarlo == 1))) {
			$lvrstart2 = 'RED';
			$lvrbRp = 1;	
		} elsif ((($lvrstart2 eq 'blue') and ($lvrsetup == 1)) or (($lvrstart2 eq 'BLUE') and ($lvrsetup == 1))) {
			$lvrstart2 = 'RED';
			$lvrbRp = 1;
		} elsif ((($lvrstart2 eq 'blue') and ($lvrsetup == 0) and ($lvrfuturecarlo == 1)) or (($lvrstart2 eq 'BLUE') and ($lvrsetup == 0) and ($lvrfuturecarlo == 1))) {
			$lvrstart2 = 'BLACK';
			$lvrbBp = 1;		
		} elsif (($lvrstart2 eq 'black') or ($lvrstart2 eq 'BLACK')) {
			if (($lvrsetup == 0) and ($lvrfuturecarlo != 1)) {
				$lvrstart2 = 'BLACK';
				$lvrbBp = 1;
			} elsif ($lvrsetup == 1) {
				$lvrstart2 = 'BLACK';
				$lvrbBp = 1;
			} else {
				$lvrstart2 = ' ';
			}															
		} else {
			$lvrstart2 = ' ';
		}
	newlines();	
	lvrmainspin2();
}

sub lvrreset {
	$lvraddmoney = 0;
	$lvrmoney = 0;
	$lvrreelspin = 0;
	if (($lvrsetup != 0) and ($lvrstart2 eq 'P2')) {
		$lvrb2p = 0;	
		$lvrb4p = 0;
		$lvrb8p = 0;
		$lvrb16p = 0;
		$lvrb32p = 0;
		$lvrstart2 = ' ';
	}
}

sub lvraddmoney {
	if (($lvrwinnbr eq '37') and ($lvrstart2 eq '0')) {
		$lvraddmoney = $lvrbet * 36;
		$lvrstwin = $lvrstwin + 1;	
	} elsif ($lvrstart2 eq 'EVEN') {
		if (($lvrwinnbr eq '2') 
		or ($lvrwinnbr eq '4')
		or ($lvrwinnbr eq '6')
		or ($lvrwinnbr eq '8')
		or ($lvrwinnbr eq '10')
		or ($lvrwinnbr eq '12')
		or ($lvrwinnbr eq '14')
		or ($lvrwinnbr eq '16')
		or ($lvrwinnbr eq '18')
		or ($lvrwinnbr eq '20')
		or ($lvrwinnbr eq '22')
		or ($lvrwinnbr eq '24')
		or ($lvrwinnbr eq '26')
		or ($lvrwinnbr eq '28')
		or ($lvrwinnbr eq '30')
		or ($lvrwinnbr eq '32')
		or ($lvrwinnbr eq '34')
		or ($lvrwinnbr eq '36')) {
			$lvraddmoney = $lvrbet * 2;
			$lvrstwin = $lvrstwin + 1;
		} else {
			$lvraddmoney = 0;
			$lvrstlose = $lvrstlose + 1;
		}
	} elsif ($lvrstart2 eq 'ODD') {
		if (($lvrwinnbr eq '1') 
		or ($lvrwinnbr eq '3')
		or ($lvrwinnbr eq '5')
		or ($lvrwinnbr eq '7')
		or ($lvrwinnbr eq '9')
		or ($lvrwinnbr eq '11')
		or ($lvrwinnbr eq '13')
		or ($lvrwinnbr eq '15')
		or ($lvrwinnbr eq '17')
		or ($lvrwinnbr eq '19')
		or ($lvrwinnbr eq '21')
		or ($lvrwinnbr eq '23')
		or ($lvrwinnbr eq '25')
		or ($lvrwinnbr eq '27')
		or ($lvrwinnbr eq '29')
		or ($lvrwinnbr eq '31')
		or ($lvrwinnbr eq '33')
		or ($lvrwinnbr eq '35')) {
			$lvraddmoney = $lvrbet * 2;
			$lvrstwin = $lvrstwin + 1;
		} else {
			$lvraddmoney = 0;
			$lvrstlose = $lvrstlose + 1;
		}
	} elsif ($lvrstart2 eq 'LOWER18') {
		if (($lvrwinnbr eq '1') 
		or ($lvrwinnbr eq '2')
		or ($lvrwinnbr eq '3')
		or ($lvrwinnbr eq '4')
		or ($lvrwinnbr eq '5')
		or ($lvrwinnbr eq '6')
		or ($lvrwinnbr eq '7')
		or ($lvrwinnbr eq '8')
		or ($lvrwinnbr eq '9')
		or ($lvrwinnbr eq '10')
		or ($lvrwinnbr eq '11')
		or ($lvrwinnbr eq '12')
		or ($lvrwinnbr eq '13')
		or ($lvrwinnbr eq '14')
		or ($lvrwinnbr eq '15')
		or ($lvrwinnbr eq '16')
		or ($lvrwinnbr eq '17')
		or ($lvrwinnbr eq '18')) {
			$lvraddmoney = $lvrbet * 2;
			$lvrstwin = $lvrstwin + 1;
		} else {
			$lvraddmoney = 0;
			$lvrstlose = $lvrstlose + 1;
		}
	} elsif ($lvrstart2 eq 'UPPER18') {
		if (($lvrwinnbr eq '19') 
		or ($lvrwinnbr eq '20')
		or ($lvrwinnbr eq '21')
		or ($lvrwinnbr eq '22')
		or ($lvrwinnbr eq '23')
		or ($lvrwinnbr eq '24')
		or ($lvrwinnbr eq '25')
		or ($lvrwinnbr eq '26')
		or ($lvrwinnbr eq '27')
		or ($lvrwinnbr eq '28')
		or ($lvrwinnbr eq '29')
		or ($lvrwinnbr eq '30')
		or ($lvrwinnbr eq '31')
		or ($lvrwinnbr eq '32')
		or ($lvrwinnbr eq '33')
		or ($lvrwinnbr eq '34')
		or ($lvrwinnbr eq '35')
		or ($lvrwinnbr eq '36')) {
			$lvraddmoney = $lvrbet * 2;
			$lvrstwin = $lvrstwin + 1;
		} else {
			$lvraddmoney = 0;
			$lvrstlose = $lvrstlose + 1;
		}
	} elsif ($lvrstart2 eq 'BLACK') {
		if (($lvrwinnbr eq '15') 
		or ($lvrwinnbr eq '4')
		or ($lvrwinnbr eq '2')
		or ($lvrwinnbr eq '17')
		or ($lvrwinnbr eq '6')
		or ($lvrwinnbr eq '13')
		or ($lvrwinnbr eq '11')
		or ($lvrwinnbr eq '8')
		or ($lvrwinnbr eq '10')
		or ($lvrwinnbr eq '24')
		or ($lvrwinnbr eq '33')
		or ($lvrwinnbr eq '20')
		or ($lvrwinnbr eq '31')
		or ($lvrwinnbr eq '22')
		or ($lvrwinnbr eq '29')
		or ($lvrwinnbr eq '28')
		or ($lvrwinnbr eq '35')
		or ($lvrwinnbr eq '26')) {
			$lvraddmoney = $lvrbet * 2;
			$lvrstwin = $lvrstwin + 1;
		} else {
			$lvraddmoney = 0;
			$lvrstlose = $lvrstlose + 1;
		}
	} elsif ($lvrstart2 eq 'RED') {
		if (($lvrwinnbr eq '32') 
		or ($lvrwinnbr eq '19')
		or ($lvrwinnbr eq '21')
		or ($lvrwinnbr eq '25')
		or ($lvrwinnbr eq '34')
		or ($lvrwinnbr eq '27')
		or ($lvrwinnbr eq '36')
		or ($lvrwinnbr eq '30')
		or ($lvrwinnbr eq '23')
		or ($lvrwinnbr eq '5')
		or ($lvrwinnbr eq '16')
		or ($lvrwinnbr eq '1')
		or ($lvrwinnbr eq '14')
		or ($lvrwinnbr eq '9')
		or ($lvrwinnbr eq '18')
		or ($lvrwinnbr eq '7')
		or ($lvrwinnbr eq '12')
		or ($lvrwinnbr eq '3')) {
			$lvraddmoney = $lvrbet * 2;
			$lvrstwin = $lvrstwin + 1;
		} else {
			$lvraddmoney = 0;
			$lvrstlose = $lvrstlose + 1;
		}				
	} elsif ($lvrstart2 eq 'C1') {
		if (($lvrwinnbr eq '1') 
		or ($lvrwinnbr eq '4')
		or ($lvrwinnbr eq '7')
		or ($lvrwinnbr eq '10')
		or ($lvrwinnbr eq '13')
		or ($lvrwinnbr eq '16')
		or ($lvrwinnbr eq '19')
		or ($lvrwinnbr eq '22')
		or ($lvrwinnbr eq '25')
		or ($lvrwinnbr eq '28')
		or ($lvrwinnbr eq '31')
		or ($lvrwinnbr eq '34')) {
			$lvraddmoney = $lvrbet * 3;
			$lvrstwin = $lvrstwin + 1;
		} else {
			$lvraddmoney = 0;
			$lvrstlose = $lvrstlose + 1;
		}
	} elsif ($lvrstart2 eq 'C2') {
		if (($lvrwinnbr eq '2') 
		or ($lvrwinnbr eq '5')
		or ($lvrwinnbr eq '8')
		or ($lvrwinnbr eq '11')
		or ($lvrwinnbr eq '14')
		or ($lvrwinnbr eq '17')
		or ($lvrwinnbr eq '20')
		or ($lvrwinnbr eq '23')
		or ($lvrwinnbr eq '26')
		or ($lvrwinnbr eq '29')
		or ($lvrwinnbr eq '32')
		or ($lvrwinnbr eq '35')) {
			$lvraddmoney = $lvrbet * 3;
			$lvrstwin = $lvrstwin + 1;
		} else {
			$lvraddmoney = 0;
			$lvrstlose = $lvrstlose + 1;
		}
	} elsif ($lvrstart2 eq 'C3') {
		if (($lvrwinnbr eq '3') 
		or ($lvrwinnbr eq '6')
		or ($lvrwinnbr eq '9')
		or ($lvrwinnbr eq '12')
		or ($lvrwinnbr eq '15')
		or ($lvrwinnbr eq '18')
		or ($lvrwinnbr eq '21')
		or ($lvrwinnbr eq '24')
		or ($lvrwinnbr eq '27')
		or ($lvrwinnbr eq '30')
		or ($lvrwinnbr eq '33')
		or ($lvrwinnbr eq '36')) {
			$lvraddmoney = $lvrbet * 3;
			$lvrstwin = $lvrstwin + 1;
		} else {
			$lvraddmoney = 0;
			$lvrstlose = $lvrstlose + 1;
		}
	} elsif ($lvrstart2 eq 'G1') {
		if (($lvrwinnbr eq '1') 
		or ($lvrwinnbr eq '2')
		or ($lvrwinnbr eq '3')
		or ($lvrwinnbr eq '4')
		or ($lvrwinnbr eq '5')
		or ($lvrwinnbr eq '6')
		or ($lvrwinnbr eq '7')
		or ($lvrwinnbr eq '8')
		or ($lvrwinnbr eq '9')) {
			$lvraddmoney = $lvrbet * 4;
			$lvrstwin = $lvrstwin + 1;
		} else {
			$lvraddmoney = 0;
			$lvrstlose = $lvrstlose + 1;
		}
	} elsif ($lvrstart2 eq 'G2') {
		if (($lvrwinnbr eq '10') 
		or ($lvrwinnbr eq '11')
		or ($lvrwinnbr eq '12')
		or ($lvrwinnbr eq '13')
		or ($lvrwinnbr eq '14')
		or ($lvrwinnbr eq '15')
		or ($lvrwinnbr eq '16')
		or ($lvrwinnbr eq '17')
		or ($lvrwinnbr eq '18')) {
			$lvraddmoney = $lvrbet * 4;
			$lvrstwin = $lvrstwin + 1;
		} else {
			$lvraddmoney = 0;
			$lvrstlose = $lvrstlose + 1;
		}
	} elsif ($lvrstart2 eq 'G3') {
		if (($lvrwinnbr eq '19') 
		or ($lvrwinnbr eq '20')
		or ($lvrwinnbr eq '21')
		or ($lvrwinnbr eq '22')
		or ($lvrwinnbr eq '23')
		or ($lvrwinnbr eq '24')
		or ($lvrwinnbr eq '25')
		or ($lvrwinnbr eq '26')
		or ($lvrwinnbr eq '27')) {
			$lvraddmoney = $lvrbet * 4;
			$lvrstwin = $lvrstwin + 1;
		} else {
			$lvraddmoney = 0;
			$lvrstlose = $lvrstlose + 1;
		}	
	} elsif ($lvrstart2 eq 'G4') {
		if (($lvrwinnbr eq '28') 
		or ($lvrwinnbr eq '29')
		or ($lvrwinnbr eq '30')
		or ($lvrwinnbr eq '31')
		or ($lvrwinnbr eq '32')
		or ($lvrwinnbr eq '33')
		or ($lvrwinnbr eq '34')
		or ($lvrwinnbr eq '35')
		or ($lvrwinnbr eq '36')) {
			$lvraddmoney = $lvrbet * 4;
			$lvrstwin = $lvrstwin + 1;
		} else {
			$lvraddmoney = 0;
			$lvrstlose = $lvrstlose + 1;
		}
	} elsif ($lvrstart2 eq 'L1') {
		if (($lvrwinnbr eq '1') 
		or ($lvrwinnbr eq '2')
		or ($lvrwinnbr eq '3')) {
			$lvraddmoney = $lvrbet * 12;
			$lvrstwin = $lvrstwin + 1;
		} else {
			$lvraddmoney = 0;
			$lvrstlose = $lvrstlose + 1;
		}
	} elsif ($lvrstart2 eq 'L2') {
		if (($lvrwinnbr eq '4') 
		or ($lvrwinnbr eq '5')
		or ($lvrwinnbr eq '6')) {
			$lvraddmoney = $lvrbet * 12;
			$lvrstwin = $lvrstwin + 1;
		} else {
			$lvraddmoney = 0;
			$lvrstlose = $lvrstlose + 1;
		}
	} elsif ($lvrstart2 eq 'L3') {
		if (($lvrwinnbr eq '7') 
		or ($lvrwinnbr eq '8')
		or ($lvrwinnbr eq '9')) {
			$lvraddmoney = $lvrbet * 12;
			$lvrstwin = $lvrstwin + 1;
		} else {
			$lvraddmoney = 0;
			$lvrstlose = $lvrstlose + 1;
		}
	} elsif ($lvrstart2 eq 'L4') {
		if (($lvrwinnbr eq '10') 
		or ($lvrwinnbr eq '11')
		or ($lvrwinnbr eq '12')) {
			$lvraddmoney = $lvrbet * 12;
			$lvrstwin = $lvrstwin + 1;
		} else {
			$lvraddmoney = 0;
			$lvrstlose = $lvrstlose + 1;
		}
	} elsif ($lvrstart2 eq 'L5') {
		if (($lvrwinnbr eq '13') 
		or ($lvrwinnbr eq '14')
		or ($lvrwinnbr eq '15')) {
			$lvraddmoney = $lvrbet * 12;
			$lvrstwin = $lvrstwin + 1;
		} else {
			$lvraddmoney = 0;
			$lvrstlose = $lvrstlose + 1;
		}
	} elsif ($lvrstart2 eq 'L6') {
		if (($lvrwinnbr eq '16') 
		or ($lvrwinnbr eq '17')
		or ($lvrwinnbr eq '18')) {
			$lvraddmoney = $lvrbet * 12;
			$lvrstwin = $lvrstwin + 1;
		} else {
			$lvraddmoney = 0;
			$lvrstlose = $lvrstlose + 1;
		}
	} elsif ($lvrstart2 eq 'L7') {
		if (($lvrwinnbr eq '19') 
		or ($lvrwinnbr eq '20')
		or ($lvrwinnbr eq '21')) {
			$lvraddmoney = $lvrbet * 12;
			$lvrstwin = $lvrstwin + 1;
		} else {
			$lvraddmoney = 0;
			$lvrstlose = $lvrstlose + 1;
		}
	} elsif ($lvrstart2 eq 'L8') {
		if (($lvrwinnbr eq '22') 
		or ($lvrwinnbr eq '23')
		or ($lvrwinnbr eq '24')) {
			$lvraddmoney = $lvrbet * 12;
			$lvrstwin = $lvrstwin + 1;
		} else {
			$lvraddmoney = 0;
			$lvrstlose = $lvrstlose + 1;
		}
	} elsif ($lvrstart2 eq 'L9') {
		if (($lvrwinnbr eq '25') 
		or ($lvrwinnbr eq '26')
		or ($lvrwinnbr eq '27')) {
			$lvraddmoney = $lvrbet * 12;
			$lvrstwin = $lvrstwin + 1;
		} else {
			$lvraddmoney = 0;
			$lvrstlose = $lvrstlose + 1;
		}
	} elsif ($lvrstart2 eq 'L10') {
		if (($lvrwinnbr eq '28') 
		or ($lvrwinnbr eq '29')
		or ($lvrwinnbr eq '30')) {
			$lvraddmoney = $lvrbet * 12;
			$lvrstwin = $lvrstwin + 1;
		} else {
			$lvraddmoney = 0;
			$lvrstlose = $lvrstlose + 1;
		}
	} elsif ($lvrstart2 eq 'L11') {
		if (($lvrwinnbr eq '31') 
		or ($lvrwinnbr eq '32')
		or ($lvrwinnbr eq '33')) {
			$lvraddmoney = $lvrbet * 12;
			$lvrstwin = $lvrstwin + 1;
		} else {
			$lvraddmoney = 0;
			$lvrstlose = $lvrstlose + 1;
		}
	} elsif ($lvrstart2 eq 'L12') {
		if (($lvrwinnbr eq '34') 
		or ($lvrwinnbr eq '35')
		or ($lvrwinnbr eq '36')) {
			$lvraddmoney = $lvrbet * 12;
			$lvrstwin = $lvrstwin + 1;
		} else {
			$lvraddmoney = 0;
			$lvrstlose = $lvrstlose + 1;
		}
	} elsif ($lvrstart2 eq 'ZC') {
		#37 = 0
		if (($lvrwinnbr eq '37') 
		or ($lvrwinnbr eq '1')
		or ($lvrwinnbr eq '2')
		or ($lvrwinnbr eq '3')) {
			$lvraddmoney = $lvrbet * 9;
			$lvrstwin = $lvrstwin + 1;
		} else {
			$lvraddmoney = 0;
			$lvrstlose = $lvrstlose + 1;
		}
	} elsif ($lvrstart2 eq 'F1') {
		if (($lvrwinnbr eq '1') 
		or ($lvrwinnbr eq '2')
		or ($lvrwinnbr eq '4')
		or ($lvrwinnbr eq '5')
		or ($lvrwinnbr eq '6')
		or ($lvrwinnbr eq '7')
		or ($lvrwinnbr eq '8')
		or ($lvrwinnbr eq '9')
		or ($lvrwinnbr eq '10')
		or ($lvrwinnbr eq '11')
		or ($lvrwinnbr eq '12')
		or ($lvrwinnbr eq '13')
		or ($lvrwinnbr eq '14')
		or ($lvrwinnbr eq '15')
		or ($lvrwinnbr eq '16')
		or ($lvrwinnbr eq '17')
		or ($lvrwinnbr eq '18')
		or ($lvrwinnbr eq '19')
		or ($lvrwinnbr eq '20')
		or ($lvrwinnbr eq '21')
		or ($lvrwinnbr eq '22')
		or ($lvrwinnbr eq '23')
		or ($lvrwinnbr eq '24')
		or ($lvrwinnbr eq '25')
		or ($lvrwinnbr eq '26')
		or ($lvrwinnbr eq '27')) {
			$lvraddmoney = ($lvrbet + ($lvrbet/3));
			$lvraddmoney = int($lvraddmoney);
			$lvrstwin = $lvrstwin + 1;
		} else {
			$lvraddmoney = 0;
			$lvrstlose = $lvrstlose + 1;
		}
	} elsif ($lvrstart2 eq 'F2') {
		if (($lvrwinnbr eq '10') 
		or ($lvrwinnbr eq '11')
		or ($lvrwinnbr eq '12')
		or ($lvrwinnbr eq '13')
		or ($lvrwinnbr eq '14')
		or ($lvrwinnbr eq '15')
		or ($lvrwinnbr eq '16')
		or ($lvrwinnbr eq '17')
		or ($lvrwinnbr eq '18')
		or ($lvrwinnbr eq '19')
		or ($lvrwinnbr eq '20')
		or ($lvrwinnbr eq '21')
		or ($lvrwinnbr eq '22')
		or ($lvrwinnbr eq '23')
		or ($lvrwinnbr eq '24')
		or ($lvrwinnbr eq '25')
		or ($lvrwinnbr eq '26')
		or ($lvrwinnbr eq '27')
		or ($lvrwinnbr eq '28')
		or ($lvrwinnbr eq '29')
		or ($lvrwinnbr eq '30')
		or ($lvrwinnbr eq '31')
		or ($lvrwinnbr eq '32')
		or ($lvrwinnbr eq '33')
		or ($lvrwinnbr eq '34')
		or ($lvrwinnbr eq '35')
		or ($lvrwinnbr eq '36')) {
			$lvraddmoney = ($lvrbet + ($lvrbet/3));
			$lvraddmoney = int($lvraddmoney);
			$lvrstwin = $lvrstwin + 1;
		} else {
			$lvraddmoney = 0;
			$lvrstlose = $lvrstlose + 1;
		}
	} elsif ($lvrstart2 eq 'F3') {
		if (($lvrwinnbr eq '1') 
		or ($lvrwinnbr eq '2')
		or ($lvrwinnbr eq '4')
		or ($lvrwinnbr eq '5')
		or ($lvrwinnbr eq '6')
		or ($lvrwinnbr eq '7')
		or ($lvrwinnbr eq '8')
		or ($lvrwinnbr eq '9')
		
		or ($lvrwinnbr eq '19')
		or ($lvrwinnbr eq '20')
		or ($lvrwinnbr eq '21')
		or ($lvrwinnbr eq '22')
		or ($lvrwinnbr eq '23')
		or ($lvrwinnbr eq '24')
		or ($lvrwinnbr eq '25')
		or ($lvrwinnbr eq '26')
		or ($lvrwinnbr eq '27')
		or ($lvrwinnbr eq '28')
		or ($lvrwinnbr eq '29')
		or ($lvrwinnbr eq '30')
		or ($lvrwinnbr eq '31')
		or ($lvrwinnbr eq '32')
		or ($lvrwinnbr eq '33')
		or ($lvrwinnbr eq '34')
		or ($lvrwinnbr eq '35')
		or ($lvrwinnbr eq '36')) {
			$lvraddmoney = ($lvrbet + ($lvrbet/3));
			$lvraddmoney = int($lvraddmoney);
			$lvrstwin = $lvrstwin + 1;
		} else {
			$lvraddmoney = 0;
			$lvrstlose = $lvrstlose + 1;
		}
	} elsif ($lvrstart2 eq 'F4') {
		if (($lvrwinnbr eq '1') 
		or ($lvrwinnbr eq '2')
		or ($lvrwinnbr eq '4')
		or ($lvrwinnbr eq '5')
		or ($lvrwinnbr eq '6')
		or ($lvrwinnbr eq '7')
		or ($lvrwinnbr eq '8')
		or ($lvrwinnbr eq '9')
		or ($lvrwinnbr eq '10') 
		or ($lvrwinnbr eq '11')
		or ($lvrwinnbr eq '12')
		or ($lvrwinnbr eq '13')
		or ($lvrwinnbr eq '14')
		or ($lvrwinnbr eq '15')
		or ($lvrwinnbr eq '16')
		or ($lvrwinnbr eq '17')
		or ($lvrwinnbr eq '18')
		or ($lvrwinnbr eq '28')
		
		or ($lvrwinnbr eq '29')
		or ($lvrwinnbr eq '30')
		or ($lvrwinnbr eq '31')
		or ($lvrwinnbr eq '32')
		or ($lvrwinnbr eq '33')
		or ($lvrwinnbr eq '34')
		or ($lvrwinnbr eq '35')
		or ($lvrwinnbr eq '36')) {
			$lvraddmoney = ($lvrbet + ($lvrbet/3));
			$lvraddmoney = int($lvraddmoney);
			$lvrstwin = $lvrstwin + 1;
		} else {
			$lvraddmoney = 0;
			$lvrstlose = $lvrstlose + 1;
		}
	} elsif ($lvrstart2 eq 'T1') {
		if (($lvrwinnbr eq '1') 
		or ($lvrwinnbr eq '2')
		or ($lvrwinnbr eq '3')
		or ($lvrwinnbr eq '4')
		or ($lvrwinnbr eq '5')
		or ($lvrwinnbr eq '6')
		or ($lvrwinnbr eq '7')
		or ($lvrwinnbr eq '8')
		or ($lvrwinnbr eq '9')
		or ($lvrwinnbr eq '10')
		or ($lvrwinnbr eq '11')
		or ($lvrwinnbr eq '12')
		or ($lvrwinnbr eq '13')
		or ($lvrwinnbr eq '14')
		or ($lvrwinnbr eq '15')
		or ($lvrwinnbr eq '16')
		or ($lvrwinnbr eq '17')
		or ($lvrwinnbr eq '18')
		or ($lvrwinnbr eq '19')
		or ($lvrwinnbr eq '20')
		or ($lvrwinnbr eq '21')
		or ($lvrwinnbr eq '22')
		or ($lvrwinnbr eq '23')
		or ($lvrwinnbr eq '24')) {
			$lvraddmoney = $lvrbet * 1.5;
			$lvraddmoney = int($lvraddmoney);
			$lvrstwin = $lvrstwin + 1;
		} else {
			$lvraddmoney = 0;
			$lvrstlose = $lvrstlose + 1;
		}
	} elsif ($lvrstart2 eq 'T2') {
		if (($lvrwinnbr eq '7') 
		or ($lvrwinnbr eq '8')
		or ($lvrwinnbr eq '9')
		or ($lvrwinnbr eq '10')
		or ($lvrwinnbr eq '11')
		or ($lvrwinnbr eq '12')
		or ($lvrwinnbr eq '13')
		or ($lvrwinnbr eq '14')
		or ($lvrwinnbr eq '15')
		or ($lvrwinnbr eq '16')
		or ($lvrwinnbr eq '17')
		or ($lvrwinnbr eq '18')
		or ($lvrwinnbr eq '19')
		or ($lvrwinnbr eq '20')
		or ($lvrwinnbr eq '21')
		or ($lvrwinnbr eq '22')
		or ($lvrwinnbr eq '23')
		or ($lvrwinnbr eq '24')
		or ($lvrwinnbr eq '25')
		or ($lvrwinnbr eq '26')
		or ($lvrwinnbr eq '27')
		or ($lvrwinnbr eq '28')
		or ($lvrwinnbr eq '29')
		or ($lvrwinnbr eq '30')) {
			$lvraddmoney = $lvrbet * 1.5;
			$lvraddmoney = int($lvraddmoney);
			$lvrstwin = $lvrstwin + 1;
		} else {
			$lvraddmoney = 0;
			$lvrstlose = $lvrstlose + 1;
		}
	} elsif ($lvrstart2 eq 'T3') {
		if (($lvrwinnbr eq '13') 
		or ($lvrwinnbr eq '14')
		or ($lvrwinnbr eq '15')
		or ($lvrwinnbr eq '16')
		or ($lvrwinnbr eq '17')
		or ($lvrwinnbr eq '18')
		or ($lvrwinnbr eq '19')
		or ($lvrwinnbr eq '20')
		or ($lvrwinnbr eq '21')
		or ($lvrwinnbr eq '22')
		or ($lvrwinnbr eq '23')
		or ($lvrwinnbr eq '24')
		or ($lvrwinnbr eq '25')
		or ($lvrwinnbr eq '26')
		or ($lvrwinnbr eq '27')
		or ($lvrwinnbr eq '28')
		or ($lvrwinnbr eq '29')
		or ($lvrwinnbr eq '30')
		or ($lvrwinnbr eq '31')
		or ($lvrwinnbr eq '32')
		or ($lvrwinnbr eq '33')
		or ($lvrwinnbr eq '34')
		or ($lvrwinnbr eq '35')
		or ($lvrwinnbr eq '36')) {
			$lvraddmoney = $lvrbet * 1.5;
			$lvraddmoney = int($lvraddmoney);
			$lvrstwin = $lvrstwin + 1;
		} else {
			$lvraddmoney = 0;
			$lvrstlose = $lvrstlose + 1;
		}
	} elsif ($lvrstart2 eq 'VOISINS') {
		$buff0 = ($lvrbet/9);
		if (($lvrwinnbr eq '4')
		or ($lvrwinnbr eq '7')
		or ($lvrwinnbr eq '12')
		or ($lvrwinnbr eq '15')
		or ($lvrwinnbr eq '18')
		or ($lvrwinnbr eq '21')
		or ($lvrwinnbr eq '19')
		or ($lvrwinnbr eq '22')
		or ($lvrwinnbr eq '32')
		or ($lvrwinnbr eq '35')) {
		#The Splits (1 "chip" on each of the splits)
			$lvraddmoney = $buff0 * 18;
			$lvraddmoney = int($lvraddmoney);
			$lvrstwin = $lvrstwin + 1;
		} elsif (($lvrwinnbr eq '25')
		or ($lvrwinnbr eq '26')
		or ($lvrwinnbr eq '28')
		or ($lvrwinnbr eq '29')) {
		#The corner (2 "chips" on the corner)
			$lvraddmoney = $buff0 * 18;
			$lvraddmoney = int($lvraddmoney);
			$lvrstwin = $lvrstwin + 1;
		} elsif (($lvrwinnbr eq '37')
		or ($lvrwinnbr eq '2')
		or ($lvrwinnbr eq '3')) {
		#The triple (2 "chips" on the triple)
		#37 is zero (green)
			$lvraddmoney = $buff0 * 24;
			$lvraddmoney = int($lvraddmoney);
			$lvrstwin = $lvrstwin + 1;
		} else {
			$lvraddmoney = 0;
			$lvrstlose = $lvrstlose + 1;
		}
		$buff0 = '';
	} elsif ($lvrstart2 eq 'TIERS') {
		$buff0 = ($lvrbet/6);
		if (($lvrwinnbr eq '5')
		or ($lvrwinnbr eq '8')
		or ($lvrwinnbr eq '10')
		or ($lvrwinnbr eq '11')
		or ($lvrwinnbr eq '13')
		or ($lvrwinnbr eq '16')
		or ($lvrwinnbr eq '23')
		or ($lvrwinnbr eq '24')
		or ($lvrwinnbr eq '27')
		or ($lvrwinnbr eq '30')
		or ($lvrwinnbr eq '33')
		or ($lvrwinnbr eq '36')) {
		#The Splits (1 "chip" on each of the splits)
			$lvraddmoney = $buff0 * 18;
			$lvraddmoney = int($lvraddmoney);
			$lvrstwin = $lvrstwin + 1;
		} else {
			$lvraddmoney = 0;
			$lvrstlose = $lvrstlose + 1;
		}
		$buff0 = '';
	} elsif ($lvrstart2 eq 'ORPHELINS') {
		$buff0 = ($lvrbet/5);
		if (($lvrwinnbr eq '1')
		or ($lvrwinnbr eq '17')) {
		#The Straight Up (1 "chip" on "1")
		#17 is a split that is in both 14/17 and 17/20 thus would win both
			$lvraddmoney = $buff0 * 36;
			$lvraddmoney = int($lvraddmoney);
			$lvrstwin = $lvrstwin + 1;
		} elsif (($lvrwinnbr eq '6')
		or ($lvrwinnbr eq '9')
		or ($lvrwinnbr eq '14')
		or ($lvrwinnbr eq '20')
		or ($lvrwinnbr eq '31')
		or ($lvrwinnbr eq '34')) {
		#The Splits (1 "chip" on each of the splits)
			$lvraddmoney = $buff0 * 18;
			$lvraddmoney = int($lvraddmoney);
			$lvrstwin = $lvrstwin + 1;
		} else {
			$lvraddmoney = 0;
			$lvrstlose = $lvrstlose + 1;
		}
		$buff0 = '';	
	} elsif (($lvrsetup == 0) and ($lvrstart2 eq 'P2')) {
		#Valid for only Monte Carlo Roulette
		if (($lvrwinnbr eq '2') 
		or ($lvrwinnbr eq '4')
		or ($lvrwinnbr eq '8')
		or ($lvrwinnbr eq '16') 
		or ($lvrwinnbr eq '32')) {
			$lvraddmoney = $lvrbet * 7;
			$lvrstwin = $lvrstwin + 1;
		} else {
			$lvraddmoney = 0;
			$lvrstlose = $lvrstlose + 1;
		}																	
	} elsif ($lvrstart2 eq $lvrwinnbr) {
		$lvraddmoney = $lvrbet * 36;
		$lvrstwin = $lvrstwin + 1;		
	} else {
		$lvraddmoney = 0;
		$lvrstlose = $lvrstlose + 1;
	}
	
	if ($lvrsetup == 1) {
		$lvrimprison = 0;
	} elsif ($lvraddmoney == 0) {
		if ($lvrwinnbr eq '37') {
			$lvrimprison = $lvrimprison + $lvrbet;
		} else {
			$lvrimprison = 0;
		}
	} elsif (($lvraddmoney > 0) and ($lvrimprison > 0)) {
		if ($lvrbet >= $lvrimprison) {
			$lvraddmoney = $lvraddmoney + $lvrimprison;
		}
		
		$lvrimprison = 0;
	}

	$lvrstmc = $lvrstmc + $lvraddmoney;
	$lvrmoney = $lvraddmoney;
	$money = $money + $lvraddmoney;
}

sub lvrbetspin4 {
	lvrreset();	
	lvrcolorsg();
	lvrbetcomp();
	lvrwheel();
	lvrprintmain();
	$lvrstart3 = <STDIN>;
	chomp($lvrstart3);
	
	if ($lvrstart3 > $money) {
		$lvrbet = 0;
	} elsif ($lvrstart3 <= 849) {
		$lvrbet = 0;
		#Table minimum is 850
	} else {
		$lvrbet = sprintf("%.0f", $lvrstart3 )
	}
	newlines();
	lvrmainspin2();
}

sub lvrnbrreset {
	$lvrbVOIp = 0;
	$lvrbTIEp = 0;
	$lvrbORPp = 0;
	$lvrbRp = 0;
	$lvrbBp = 0;
	$lvrb0p = 0;
	$lvrb1p = 0;
	$lvrb2p = 0;	
	$lvrb3p = 0;	
	$lvrb4p = 0;
	$lvrb5p = 0;
	$lvrb6p = 0;
	$lvrb7p = 0;	
	$lvrb8p = 0;	
	$lvrb9p = 0;
	$lvrb10p = 0;
	$lvrb11p = 0;
	$lvrb12p = 0;	
	$lvrb13p = 0;	
	$lvrb14p = 0;
	$lvrb15p = 0;
	$lvrb16p = 0;
	$lvrb17p = 0;	
	$lvrb18p = 0;	
	$lvrb19p = 0;
	$lvrb20p = 0;	
	$lvrb21p = 0;
	$lvrb22p = 0;	
	$lvrb23p = 0;	
	$lvrb24p = 0;
	$lvrb25p = 0;
	$lvrb26p = 0;
	$lvrb27p = 0;	
	$lvrb28p = 0;	
	$lvrb29p = 0;
	$lvrb30p = 0;
	$lvrb31p = 0;
	$lvrb32p = 0;	
	$lvrb33p = 0;	
	$lvrb34p = 0;
	$lvrb35p = 0;
	$lvrb36p = 0;			
}

sub lvrstdin1 {
	$lvrstart1 = <STDIN>;
	chomp($lvrstart1);
	if (($lvrstart1 eq 'P') or ($lvrstart1 eq 'p') or ($lvrstart1 eq 'a') or ($lvrstart1 eq 'A')) {
		if ($lvrstart2 eq ' ') {
			newlines();
			lvrmainspin2();
		} elsif ($lvrbet == 0) {
			newlines();
			lvrmainspin2();				
		} elsif ($money >= $lvrbet) {
			$money = $money - $lvrbet;
			$moneyexp = $moneyexp + $lvrbet;
			$lvrstmc2 = $lvrstmc2 + $lvrbet;
			$lvrstspins = $lvrstspins + 1;
			newlines();
			lvrmainspin1();
		} else {
			newlines();
			lvrmainspin2();
		}
	} elsif (($lvrstart1 eq 'N') or ($lvrstart1 eq 'n')) {
		newlines();
		lvrnbrspin3();
	} elsif (($lvrstart1 eq 'B') or ($lvrstart1 eq 'b')) {
		newlines();
		lvrbetspin4();
	} elsif (($lvrstart1 eq 'C') or ($lvrstart1 eq 'c')) {
		print "\n";
		return;
	} elsif (($lvrstart1 eq 'EXIT') or ($lvrstart1 eq 'exit') or ($lvrstart1 eq 'QUIT') or ($lvrstart1 eq 'quit')) {
		exitgame();					
	} else {
		newlines();
		lvrmainspin2();
	}
}


sub lvrcolorsg {
	if ($lvrsetup == 0) {
		if ($lvrfuturecarlo == 1) {
			lvrcolorfuturecarlo();
		} else {
			lvrcolormontecarlo();
		}
	} else {
		lvrcoloramerican();
	}
}

sub lvrcolormontecarlo {
	$lvrredvar = '  R E D ';
	$lvrblkvar = ' B L K  ';
	$lvrcolor1 = "$bgcgreen";   #0 background
	$lvrcolor2 = "$bgcblack";   #black background   
	$lvrcolor3 = "$bgcred";     #red background
	$lvrcolor4 = "$boldwhite";  #wheel forground
	$lvrcolor5 = "$bgcwhite";   #divider background
	$lvrcolor6 = "$boldwhite";  #divider forground
	$lvrcolor7 = "$bgccyan";    #border background
	$lvrcolor8 = "$boldcyan";   #border forground
	$lvrcolor9 = "$bgcblack";   #wheel2 background
	$lvrcolor10 = "$boldblack"; #wheel2 forground
	$lvrcolor11 = "$boldwhite"; #wheel2 forground
	$lvrcolor12 = "$white";     #wheel2 ball forground
	$lvrcolor13 = "$boldgreen"; #total forground
	$lvrcolor14 = "$bgcgreen";  #total background
	$lvrcolor15 = "$blue";      #title forground
	$lvrcolor16 = "$boldwhite"; #total number forground
	$lvrcolor17 = "$bgccyan";   #title number background
	$lvrcolor18 = "$boldyellow";#total highlight number forground
	$lvrcolor19 = "$bgcblue";   #title highlight number background
	$lvrcolor20 = "$boldblack"; #computer border forground
	$lvrcolor21 = "$bgcwhite";  #computer border background
	$lvrcolor22 = "$boldwhite"; #computer forground 1
	$lvrcolor23 = "$bgcblue";   #computer background 1
	$lvrcolor24 = "$boldwhite"; #computer forground 2
	$lvrcolor25 = "$bgcblue";   #computer background 2
}

sub lvrcolorfuturecarlo {
	$lvrredvar = ' MAGENTA';
	$lvrblkvar = '  BLUE  ';
	$lvrcolor1 = "$bgccyan";    #0 background
	$lvrcolor2 = "$bgcblue";    #black background   
	$lvrcolor3 = "$bgcmagenta"; #red background
	$lvrcolor4 = "$boldwhite";  #wheel forground
	$lvrcolor5 = "$bgcwhite";   #divider background
	$lvrcolor6 = "$boldwhite";  #divider forground
	$lvrcolor7 = "$bgccyan";    #border background
	$lvrcolor8 = "$boldcyan";   #border forground
	$lvrcolor9 = "$bgcblack";   #wheel2 background
	$lvrcolor10 = "$boldblack"; #wheel2 forground
	$lvrcolor11 = "$boldwhite"; #wheel2 forground
	$lvrcolor12 = "$white";     #wheel2 ball forground
	$lvrcolor13 = "$boldgreen"; #total forground
	$lvrcolor14 = "$bgcgreen";  #total background
	$lvrcolor15 = "$blue";      #title forground
	$lvrcolor16 = "$boldwhite"; #total number forground
	$lvrcolor17 = "$bgccyan";   #title number background
	$lvrcolor18 = "$boldyellow";#total highlight number forground
	$lvrcolor19 = "$bgcblue";   #title highlight number background
	$lvrcolor20 = "$boldblack"; #computer border forground
	$lvrcolor21 = "$bgcwhite";  #computer border background
	$lvrcolor22 = "$boldwhite"; #computer forground 1
	$lvrcolor23 = "$bgcblue";   #computer background 1
	$lvrcolor24 = "$boldwhite"; #computer forground 2
	$lvrcolor25 = "$bgcblue";   #computer background 2
}

sub lvrcoloramerican {
	$lvrredvar = '  B L U ';
	$lvrblkvar = ' B L K  ';
	$lvrcolor1 = "$bgcred";     #0 background
	$lvrcolor2 = "$bgcblack";   #black background   
	$lvrcolor3 = "$bgcblue";    #red background
	$lvrcolor4 = "$boldwhite";  #wheel forground
	$lvrcolor5 = "$bgcwhite";   #divider background
	$lvrcolor6 = "$boldwhite";  #divider forground
	$lvrcolor7 = "$bgcwhite";   #border background
	$lvrcolor8 = "$boldwhite";  #border forground
	$lvrcolor9 = "$bgcblack";   #wheel2 background
	$lvrcolor10 = "$boldblack"; #wheel2 forground
	$lvrcolor11 = "$boldwhite"; #wheel2 forground
	$lvrcolor12 = "$white";     #wheel2 ball forground
	$lvrcolor13 = "$boldblue";  #total forground
	$lvrcolor14 = "$bgcblue";   #total background
	$lvrcolor15 = "$blue";      #title forground
	$lvrcolor16 = "$boldblue";  #total number forground
	$lvrcolor17 = "$bgcwhite";  #title number background
	$lvrcolor18 = "$boldwhite"; #total highlight number forground
	$lvrcolor19 = "$bgcblue";   #title highlight number background
	$lvrcolor20 = "$boldblack"; #computer border forground
	$lvrcolor21 = "$bgcblack";  #computer border background
	$lvrcolor22 = "$boldwhite"; #computer forground 1
	$lvrcolor23 = "$bgcred";    #computer background 1
	$lvrcolor24 = "$blue";      #computer forground 2
	$lvrcolor25 = "$bgcwhite";  #computer background 2
}

sub lvrcolorcA {
	$lvrnbr = $lvrslotA; 
	$lvrC1 = $lvrcolor4;
	$lvrC2 = $lvrcolorA;
}

sub lvrcolorcB {
	$lvrnbr = $lvrslotB; 
	$lvrC1 = $lvrcolor4;
	$lvrC2 = $lvrcolorB;
}

sub lvrcolorcC {
	$lvrnbr = $lvrslotC; 
	$lvrC1 = $lvrcolor4;
	$lvrC2 = $lvrcolorC;
}

sub lvrcolorcD {
	$lvrnbr = $lvrslotD; 
	$lvrC1 = $lvrcolor4;
	$lvrC2 = $lvrcolorD;
}

sub lvrcolorcE {
	$lvrnbr = $lvrslotE; 
	$lvrC1 = $lvrcolor4;
	$lvrC2 = $lvrcolorE;
}

sub lvrspin {
	$lvrwinnbr = int(rand(41));
	
	if ($lvrwinnbr == 0) {
		lvrspin();
	} elsif ($lvrwinnbr >= 38) {
		lvrspin();	
	}
}

sub lvrslot1 {
	sep; print colored('         ',"$lvrC1 on_$lvrC2"); sep; 
}

sub lvrslot2 {
	sep; print colored("   $lvrnbr   ","$lvrC1 on_$lvrC2"); sep; 
}

sub lvrslot3 {
	sep; print colored('-----------',"$lvrcolor6 on_$lvrcolor5"); sep; 
}

sub lvrslot4 {
	sep; print colored(' ',"$lvrcolor6 on_$lvrcolor5"); sep; 
}

sub lvrslot5 {
	print colored('|',"$lvrcolor8 on_$lvrcolor7");
}

sub lvrslot6 {
	sep; print colored('-----------',"$lvrcolor10 on_$lvrcolor9"); sep; 
}

sub lvrslot7 {
	sep; print colored('           ',"$lvrcolor10 on_$lvrcolor9"); sep; 
}

sub lvrslot8 {
	sep; 
	if ($lvrreelspin == 0) {
		print colored('   /\\|/\\   ',"$lvrcolor11 on_$lvrcolor9");
	} elsif ($lvrreelspin == 1) {
		print colored('   /\\|/\\   ',"$lvrcolor12 on_$lvrcolor9");
	} else {
		print colored('           ',"$lvrcolor12 on_$lvrcolor9");
	}
	sep; 
}

sub lvrslot9 {
	sep; 
	if ($lvrreelspin == 0) {
		print colored('   |-X',"$lvrcolor11 on_$lvrcolor9"); print colored('-|   ',"$lvrcolor12 on_$lvrcolor9");
	} elsif ($lvrreelspin == 1) {
		print colored('   |-X-|   ',"$lvrcolor12 on_$lvrcolor9");
	} else {
		print colored('           ',"$lvrcolor12 on_$lvrcolor9");
	}
	sep; 
}

sub lvrslot10 {
	sep; 
	if ($lvrreelspin == 0) {
		print colored('   \\/',"$lvrcolor11 on_$lvrcolor9"); print colored('|\\/   ',"$lvrcolor12 on_$lvrcolor9");
	} elsif ($lvrreelspin == 1) {
		print colored('   \\/|\\/   ',"$lvrcolor12 on_$lvrcolor9");
	} else {
		print colored('           ',"$lvrcolor12 on_$lvrcolor9");
	}
	sep; 
}

sub lvrwheel {
	if ($lvrwinnbr == 37) {
		$lvrslotA = '1 5'; $lvrcolorA = $lvrcolor2;
		$lvrslotB = '3 2'; $lvrcolorB = $lvrcolor3;
		$lvrslotC = ' 0 '; $lvrcolorC = $lvrcolor1;
		$lvrslotD = '2 6'; $lvrcolorD = $lvrcolor2;
		$lvrslotE = ' 3 '; $lvrcolorE = $lvrcolor3;
	} elsif ($lvrwinnbr == 32) {
		$lvrslotA = '1 9'; $lvrcolorA = $lvrcolor3;
		$lvrslotB = '1 5'; $lvrcolorB = $lvrcolor2;
		$lvrslotC = '3 2'; $lvrcolorC = $lvrcolor3;
		$lvrslotD = ' 0 '; $lvrcolorD = $lvrcolor1;
		$lvrslotE = '2 6'; $lvrcolorE = $lvrcolor2;
	} elsif ($lvrwinnbr == 15) {
		$lvrslotA = ' 4 '; $lvrcolorA = $lvrcolor2;
		$lvrslotB = '1 9'; $lvrcolorB = $lvrcolor3;
		$lvrslotC = '1 5'; $lvrcolorC = $lvrcolor2;
		$lvrslotD = '3 2'; $lvrcolorD = $lvrcolor3;
		$lvrslotE = ' 0 '; $lvrcolorE = $lvrcolor1;
	} elsif ($lvrwinnbr == 19) {
		$lvrslotA = '2 1'; $lvrcolorA = $lvrcolor3;
		$lvrslotB = ' 4 '; $lvrcolorB = $lvrcolor2;
		$lvrslotC = '1 9'; $lvrcolorC = $lvrcolor3;
		$lvrslotD = '1 5'; $lvrcolorD = $lvrcolor2;
		$lvrslotE = '3 2'; $lvrcolorE = $lvrcolor3;
	} elsif ($lvrwinnbr == 4) {
		$lvrslotA = ' 2 '; $lvrcolorA = $lvrcolor2;
		$lvrslotB = '2 1'; $lvrcolorB = $lvrcolor3;
		$lvrslotC = ' 4 '; $lvrcolorC = $lvrcolor2;
		$lvrslotD = '1 9'; $lvrcolorD = $lvrcolor3;
		$lvrslotE = '1 5'; $lvrcolorE = $lvrcolor2;
	} elsif ($lvrwinnbr == 21) {
		$lvrslotA = '2 5'; $lvrcolorA = $lvrcolor3;
		$lvrslotB = ' 2 '; $lvrcolorB = $lvrcolor2;
		$lvrslotC = '2 1'; $lvrcolorC = $lvrcolor3;
		$lvrslotD = ' 4 '; $lvrcolorD = $lvrcolor2;
		$lvrslotE = '1 9'; $lvrcolorE = $lvrcolor3;
	} elsif ($lvrwinnbr == 2) {
		$lvrslotA = '1 7'; $lvrcolorA = $lvrcolor2;
		$lvrslotB = '2 5'; $lvrcolorB = $lvrcolor3;
		$lvrslotC = ' 2 '; $lvrcolorC = $lvrcolor2;
		$lvrslotD = '2 1'; $lvrcolorD = $lvrcolor3;
		$lvrslotE = ' 4 '; $lvrcolorE = $lvrcolor2;
	} elsif ($lvrwinnbr == 25) {
		$lvrslotA = '3 4'; $lvrcolorA = $lvrcolor3;
		$lvrslotB = '1 7'; $lvrcolorB = $lvrcolor2;
		$lvrslotC = '2 5'; $lvrcolorC = $lvrcolor3;
		$lvrslotD = ' 2 '; $lvrcolorD = $lvrcolor2;
		$lvrslotE = '2 1'; $lvrcolorE = $lvrcolor3;
	} elsif ($lvrwinnbr == 17) {
		$lvrslotA = ' 6 '; $lvrcolorA = $lvrcolor2;
		$lvrslotB = '3 4'; $lvrcolorB = $lvrcolor3;
		$lvrslotC = '1 7'; $lvrcolorC = $lvrcolor2;
		$lvrslotD = '2 5'; $lvrcolorD = $lvrcolor3;
		$lvrslotE = ' 2 '; $lvrcolorE = $lvrcolor2;
	} elsif ($lvrwinnbr == 34) {
		$lvrslotA = '2 7'; $lvrcolorA = $lvrcolor3;
		$lvrslotB = ' 6 '; $lvrcolorB = $lvrcolor2;
		$lvrslotC = '3 4'; $lvrcolorC = $lvrcolor3;
		$lvrslotD = '1 7'; $lvrcolorD = $lvrcolor2;
		$lvrslotE = '2 5'; $lvrcolorE = $lvrcolor3;
	} elsif ($lvrwinnbr == 6) {
		$lvrslotA = '1 3'; $lvrcolorA = $lvrcolor2;
		$lvrslotB = '2 7'; $lvrcolorB = $lvrcolor3;
		$lvrslotC = ' 6 '; $lvrcolorC = $lvrcolor2;
		$lvrslotD = '3 4'; $lvrcolorD = $lvrcolor3;
		$lvrslotE = '1 7'; $lvrcolorE = $lvrcolor2;
	} elsif ($lvrwinnbr == 27) {
		$lvrslotA = '3 6'; $lvrcolorA = $lvrcolor3;
		$lvrslotB = '1 3'; $lvrcolorB = $lvrcolor2;
		$lvrslotC = '2 7'; $lvrcolorC = $lvrcolor3;
		$lvrslotD = ' 6 '; $lvrcolorD = $lvrcolor2;
		$lvrslotE = '3 4'; $lvrcolorE = $lvrcolor3;
	} elsif ($lvrwinnbr == 13) {
		$lvrslotA = '1 1'; $lvrcolorA = $lvrcolor2;
		$lvrslotB = '3 6'; $lvrcolorB = $lvrcolor3;
		$lvrslotC = '1 3'; $lvrcolorC = $lvrcolor2;
		$lvrslotD = '2 7'; $lvrcolorD = $lvrcolor3;
		$lvrslotE = ' 6 '; $lvrcolorE = $lvrcolor2;
	} elsif ($lvrwinnbr == 36) {
		$lvrslotA = '3 0'; $lvrcolorA = $lvrcolor3;
		$lvrslotB = '1 1'; $lvrcolorB = $lvrcolor2;
		$lvrslotC = '3 6'; $lvrcolorC = $lvrcolor3;
		$lvrslotD = '1 3'; $lvrcolorD = $lvrcolor2;
		$lvrslotE = '2 7'; $lvrcolorE = $lvrcolor3;
	} elsif ($lvrwinnbr == 11) {
		$lvrslotA = ' 8 '; $lvrcolorA = $lvrcolor2;
		$lvrslotB = '3 0'; $lvrcolorB = $lvrcolor3;
		$lvrslotC = '1 1'; $lvrcolorC = $lvrcolor2;
		$lvrslotD = '3 6'; $lvrcolorD = $lvrcolor3;
		$lvrslotE = '1 3'; $lvrcolorE = $lvrcolor2;
	} elsif ($lvrwinnbr == 30) {
		$lvrslotA = '2 3'; $lvrcolorA = $lvrcolor3;
		$lvrslotB = ' 8 '; $lvrcolorB = $lvrcolor2;
		$lvrslotC = '3 0'; $lvrcolorC = $lvrcolor3;
		$lvrslotD = '1 1'; $lvrcolorD = $lvrcolor2;
		$lvrslotE = '3 6'; $lvrcolorE = $lvrcolor3;
	} elsif ($lvrwinnbr == 8) {
		$lvrslotA = '1 0'; $lvrcolorA = $lvrcolor2;
		$lvrslotB = '2 3'; $lvrcolorB = $lvrcolor3;
		$lvrslotC = ' 8 '; $lvrcolorC = $lvrcolor2;
		$lvrslotD = '3 0'; $lvrcolorD = $lvrcolor3;
		$lvrslotE = '1 1'; $lvrcolorE = $lvrcolor2;
	} elsif ($lvrwinnbr == 23) {
		$lvrslotA = ' 5 '; $lvrcolorA = $lvrcolor3;
		$lvrslotB = '1 0'; $lvrcolorB = $lvrcolor2;
		$lvrslotC = '2 3'; $lvrcolorC = $lvrcolor3;
		$lvrslotD = ' 8 '; $lvrcolorD = $lvrcolor2;
		$lvrslotE = '3 0'; $lvrcolorE = $lvrcolor3;
	} elsif ($lvrwinnbr == 10) {
		$lvrslotA = '2 4'; $lvrcolorA = $lvrcolor2;
		$lvrslotB = ' 5 '; $lvrcolorB = $lvrcolor3;
		$lvrslotC = '1 0'; $lvrcolorC = $lvrcolor2;
		$lvrslotD = '2 3'; $lvrcolorD = $lvrcolor3;
		$lvrslotE = ' 8 '; $lvrcolorE = $lvrcolor2;
	} elsif ($lvrwinnbr == 5) {
		$lvrslotA = '1 6'; $lvrcolorA = $lvrcolor3;
		$lvrslotB = '2 4'; $lvrcolorB = $lvrcolor2;
		$lvrslotC = ' 5 '; $lvrcolorC = $lvrcolor3;
		$lvrslotD = '1 0'; $lvrcolorD = $lvrcolor2;
		$lvrslotE = '2 3'; $lvrcolorE = $lvrcolor3;
	} elsif ($lvrwinnbr == 24) {
		$lvrslotA = '3 3'; $lvrcolorA = $lvrcolor2;
		$lvrslotB = '1 6'; $lvrcolorB = $lvrcolor3;
		$lvrslotC = '2 4'; $lvrcolorC = $lvrcolor2;
		$lvrslotD = ' 5 '; $lvrcolorD = $lvrcolor3;
		$lvrslotE = '1 0'; $lvrcolorE = $lvrcolor2;
	} elsif ($lvrwinnbr == 16) {
		$lvrslotA = ' 1 '; $lvrcolorA = $lvrcolor3;
		$lvrslotB = '3 3'; $lvrcolorB = $lvrcolor2;
		$lvrslotC = '1 6'; $lvrcolorC = $lvrcolor3;
		$lvrslotD = '2 4'; $lvrcolorD = $lvrcolor2;
		$lvrslotE = ' 5 '; $lvrcolorE = $lvrcolor3;
	} elsif ($lvrwinnbr == 33) {
		$lvrslotA = '2 0'; $lvrcolorA = $lvrcolor2;
		$lvrslotB = ' 1 '; $lvrcolorB = $lvrcolor3;
		$lvrslotC = '3 3'; $lvrcolorC = $lvrcolor2;
		$lvrslotD = '1 6'; $lvrcolorD = $lvrcolor3;
		$lvrslotE = '2 4'; $lvrcolorE = $lvrcolor2;
	} elsif ($lvrwinnbr == 1) {
		$lvrslotA = '1 4'; $lvrcolorA = $lvrcolor3;
		$lvrslotB = '2 0'; $lvrcolorB = $lvrcolor2;
		$lvrslotC = ' 1 '; $lvrcolorC = $lvrcolor3;
		$lvrslotD = '3 3'; $lvrcolorD = $lvrcolor2;
		$lvrslotE = '1 6'; $lvrcolorE = $lvrcolor3;
	} elsif ($lvrwinnbr == 20) {
		$lvrslotA = '3 1'; $lvrcolorA = $lvrcolor2;
		$lvrslotB = '1 4'; $lvrcolorB = $lvrcolor3;
		$lvrslotC = '2 0'; $lvrcolorC = $lvrcolor2;
		$lvrslotD = ' 1 '; $lvrcolorD = $lvrcolor3;
		$lvrslotE = '3 3'; $lvrcolorE = $lvrcolor2;
	} elsif ($lvrwinnbr == 14) {
		$lvrslotA = ' 9 '; $lvrcolorA = $lvrcolor3;
		$lvrslotB = '3 1'; $lvrcolorB = $lvrcolor2;
		$lvrslotC = '1 4'; $lvrcolorC = $lvrcolor3;
		$lvrslotD = '2 0'; $lvrcolorD = $lvrcolor2;
		$lvrslotE = ' 1 '; $lvrcolorE = $lvrcolor3;
	} elsif ($lvrwinnbr == 31) {
		$lvrslotA = '2 2'; $lvrcolorA = $lvrcolor2;
		$lvrslotB = ' 9 '; $lvrcolorB = $lvrcolor3;
		$lvrslotC = '3 1'; $lvrcolorC = $lvrcolor2;
		$lvrslotD = '1 4'; $lvrcolorD = $lvrcolor3;
		$lvrslotE = '2 0'; $lvrcolorE = $lvrcolor2;
	} elsif ($lvrwinnbr == 9) {
		$lvrslotA = '1 8'; $lvrcolorA = $lvrcolor3;
		$lvrslotB = '2 2'; $lvrcolorB = $lvrcolor2;
		$lvrslotC = ' 9 '; $lvrcolorC = $lvrcolor3;
		$lvrslotD = '3 1'; $lvrcolorD = $lvrcolor2;
		$lvrslotE = '1 4'; $lvrcolorE = $lvrcolor3;
	} elsif ($lvrwinnbr == 22) {
		$lvrslotA = '2 9'; $lvrcolorA = $lvrcolor2;
		$lvrslotB = '1 8'; $lvrcolorB = $lvrcolor3;
		$lvrslotC = '2 2'; $lvrcolorC = $lvrcolor2;
		$lvrslotD = ' 9 '; $lvrcolorD = $lvrcolor3;
		$lvrslotE = '3 1'; $lvrcolorE = $lvrcolor2;
	} elsif ($lvrwinnbr == 18) {
		$lvrslotA = ' 7 '; $lvrcolorA = $lvrcolor3;
		$lvrslotB = '2 9'; $lvrcolorB = $lvrcolor2;
		$lvrslotC = '1 8'; $lvrcolorC = $lvrcolor3;
		$lvrslotD = '2 2'; $lvrcolorD = $lvrcolor2;
		$lvrslotE = ' 9 '; $lvrcolorE = $lvrcolor3;
	} elsif ($lvrwinnbr == 29) {
		$lvrslotA = '2 8'; $lvrcolorA = $lvrcolor2;
		$lvrslotB = ' 7 '; $lvrcolorB = $lvrcolor3;
		$lvrslotC = '2 9'; $lvrcolorC = $lvrcolor2;
		$lvrslotD = '1 8'; $lvrcolorD = $lvrcolor3;
		$lvrslotE = '2 2'; $lvrcolorE = $lvrcolor2;
	} elsif ($lvrwinnbr == 7) {
		$lvrslotA = '1 2'; $lvrcolorA = $lvrcolor3;
		$lvrslotB = '2 8'; $lvrcolorB = $lvrcolor2;
		$lvrslotC = ' 7 '; $lvrcolorC = $lvrcolor3;
		$lvrslotD = '2 9'; $lvrcolorD = $lvrcolor2;
		$lvrslotE = '1 8'; $lvrcolorE = $lvrcolor3;
	} elsif ($lvrwinnbr == 28) {
		$lvrslotA = '3 5'; $lvrcolorA = $lvrcolor2;
		$lvrslotB = '1 2'; $lvrcolorB = $lvrcolor3;
		$lvrslotC = '2 8'; $lvrcolorC = $lvrcolor2;
		$lvrslotD = ' 7 '; $lvrcolorD = $lvrcolor3;
		$lvrslotE = '2 9'; $lvrcolorE = $lvrcolor2;
	} elsif ($lvrwinnbr == 12) {
		$lvrslotA = ' 3 '; $lvrcolorA = $lvrcolor3;
		$lvrslotB = '3 5'; $lvrcolorB = $lvrcolor2;
		$lvrslotC = '1 2'; $lvrcolorC = $lvrcolor3;
		$lvrslotD = '2 8'; $lvrcolorD = $lvrcolor2;
		$lvrslotE = ' 7 '; $lvrcolorE = $lvrcolor3;
	} elsif ($lvrwinnbr == 35) {
		$lvrslotA = '2 6'; $lvrcolorA = $lvrcolor2;
		$lvrslotB = ' 3 '; $lvrcolorB = $lvrcolor3;
		$lvrslotC = '3 5'; $lvrcolorC = $lvrcolor2;
		$lvrslotD = '1 2'; $lvrcolorD = $lvrcolor3;
		$lvrslotE = '2 8'; $lvrcolorE = $lvrcolor2;
	} elsif ($lvrwinnbr == 3) {
		$lvrslotA = ' 0 '; $lvrcolorA = $lvrcolor1;
		$lvrslotB = '2 6'; $lvrcolorB = $lvrcolor2;
		$lvrslotC = ' 3 '; $lvrcolorC = $lvrcolor3;
		$lvrslotD = '3 5'; $lvrcolorD = $lvrcolor2;
		$lvrslotE = '1 2'; $lvrcolorE = $lvrcolor3;
	} elsif ($lvrwinnbr == 26) {
		$lvrslotA = '3 2'; $lvrcolorA = $lvrcolor3;
		$lvrslotB = ' 0 '; $lvrcolorB = $lvrcolor1;
		$lvrslotC = '2 6'; $lvrcolorC = $lvrcolor2;
		$lvrslotD = ' 3 '; $lvrcolorD = $lvrcolor3;
		$lvrslotE = '3 5'; $lvrcolorE = $lvrcolor2;
	} else {
		$lvrslotA = '0?0'; $lvrcolorA = $lvrcolor2;
		$lvrslotB = '?0?'; $lvrcolorB = $lvrcolor3;
		$lvrslotC = '0?0'; $lvrcolorC = $lvrcolor1;
		$lvrslotD = '?0?'; $lvrcolorD = $lvrcolor3;
		$lvrslotE = '0?0'; $lvrcolorE = $lvrcolor2;	
	}
}

sub lvrprintmain {
	lvrmedian1(); print"\n";
	lvrcolorcA(); lvrslot5(); lvrslot4(); lvrslot1(); lvrslot4(); lvrslot7(); lvrslot5(); lvrstatusbar2(); print"\n";
	lvrslot5(); lvrslot4(); lvrslot2(); lvrslot4(); lvrslot7(); lvrslot5(); if ($lvrsetup == 0) { lvrstatusbar3prison(); } else { lvrstatusbar3(); } print"\n";
	lvrslot5(); lvrslot4(); lvrslot1(); lvrslot4(); lvrslot7(); lvrslot5(); lvrstatusbar4(); print"\n";
	lvrslot5(); lvrslot4(); lvrslot1(); lvrslot4(); lvrslot7(); lvrslot5(); lvrstatusbar5(); print"\n";
	lvrslot5(); lvrslot3(); lvrslot6(); lvrslot5();lvrspace1rt1(); lvrb000(); lvrstatusbar6(); print"\n";

	lvrcolorcB(); lvrslot5(); lvrslot4(); lvrslot1(); lvrslot4(); lvrslot7(); lvrslot5(); lvrspace1rt2(); lvrb00(); lvrstatusbar7(); print"\n";
	lvrslot5(); lvrslot4(); lvrslot1(); lvrslot4(); lvrslot7();  lvrslot5(); lvrspace1rt3(); lvrb0(); lvrstatusbar8(); print"\n";
	lvrslot5(); lvrslot4(); lvrslot2(); lvrslot4(); lvrslot7(); lvrslot5(); lvrspace1rt4(); lvrb1(); lvrstatusbar9(); print"\n";
	lvrslot5(); lvrslot4(); lvrslot1(); lvrslot4(); lvrslot7(); lvrslot5(); lvrspace1rt5(); lvrb2(); lvrstatusbar10(); print"\n";
	lvrslot5(); lvrslot4(); lvrslot1(); lvrslot4(); lvrslot7(); lvrslot5(); lvrspace1rt6(); lvrb3(); lvrstatusbar11(); print"\n";
	lvrslot5(); lvrslot3(); lvrslot6();  lvrslot5(); lvrspace1rt7(); lvrb0(); lvrstatusbar12(); print"\n";

	lvrcolorcC(); lvrslot5(); lvrslot4(); lvrslot1(); lvrslot4(); lvrslot7(); lvrslot5(); lvrspace1rt8(); lvrb4(); lvrstatusbar13(); print"\n";
	lvrslot5(); lvrslot4(); lvrslot1(); lvrslot4(); lvrslot8(); lvrslot5(); lvrspace1rt9(); lvrb5(); lvrstatusbar14(); print"\n";
	lvrslot5(); lvrslot4(); lvrslot2(); lvrslot4(); lvrslot9(); lvrslot5(); lvrspace1rt10(); lvrb6(); lvrstatusbar15(); print"\n";
	lvrslot5(); lvrslot4(); lvrslot1(); lvrslot4(); lvrslot10(); lvrslot5(); lvrspace1rt11(); lvrb0(); lvrstatusbar16(); print"\n";
	lvrslot5(); lvrslot4(); lvrslot1(); lvrslot4(); lvrslot7(); lvrslot5(); lvrspace1rt12(); lvrb7(); lvrstatusbar17(); print"\n";
	lvrslot5(); lvrslot3(); lvrslot6(); lvrslot5(); lvrspace1rt13(); lvrb8(); lvrstatusbar18(); print"\n";

	lvrcolorcD(); lvrslot5(); lvrslot4(); lvrslot1(); lvrslot4(); lvrslot7(); lvrslot5(); lvrspace1rt14(); lvrb9(); lvrstatusbar19(); print"\n";
	lvrslot5(); lvrslot4(); lvrslot1(); lvrslot4(); lvrslot7(); lvrslot5(); lvrspace1rt15(); lvrb0(); lvrstatusbar20(); print"\n";
	lvrslot5(); lvrslot4(); lvrslot2(); lvrslot4(); lvrslot7(); lvrslot5(); lvrspace1rt16(); lvrb10(); lvrstatusbar21(); print"\n";
	lvrslot5(); lvrslot4(); lvrslot1(); lvrslot4(); lvrslot7(); lvrslot5(); lvrspace1rt17(); lvrb11(); lvrstatusbar22(); print"\n";
	lvrslot5(); lvrslot4(); lvrslot1(); lvrslot4(); lvrslot7(); lvrslot5(); lvrspace1rt18(); lvrb12(); lvrstatusbar23(); print"\n";
	lvrslot5(); lvrslot3(); lvrslot6(); lvrslot5(); lvrspace1rt19(); lvrb0(); lvrstatusbar24(); print"\n";

	lvrcolorcE(); lvrslot5(); lvrslot4(); lvrslot1(); lvrslot4(); lvrslot7(); lvrslot5(); lvrspace1rt20(); lvrb00000(); lvrstatusbar25(); print"\n";
	lvrslot5(); lvrslot4(); lvrslot1(); lvrslot4(); lvrslot7(); lvrslot5(); lvrspace1rt21(); lvrb0000(); lvrstatusbar26(); print"\n";
	lvrslot5(); lvrslot4(); lvrslot2(); lvrslot4(); lvrslot7(); lvrslot5(); lvrstatusbar3();print"\n";
	lvrslot5(); lvrslot4(); lvrslot1(); lvrslot4(); lvrslot7(); lvrslot5(); lvrstatusbar(); print"\n";
	lvrslot5(); lvrslot4(); lvrslot1(); lvrslot4(); lvrslot7(); lvrslot5(); lvrmedian3(); print"\n";
	lvrmedian2(); STDOUT->flush();
}

sub lvrmedian1 { 
	print colored('/------------------------------------------------------------------------------\\',"$lvrcolor8 on_$lvrcolor7");
}

sub lvrmedian2 { 
	print colored('\\----------------------/',"$lvrcolor8 on_$lvrcolor7");
}

sub lvrmedian3 { 
	print colored('-------------------------------------------------------/',"$lvrcolor8 on_$lvrcolor7");
}

sub lvrstatusbar {
	print colored('      WINNINGS ',"$lvrcolor8 on_$lvrcolor7");
	lvrwinnings();
	print colored('     TOTAL FUNDS ',"$lvrcolor8 on_$lvrcolor7");
	lvrtotal();
	print colored('   ',"$lvrcolor8 on_$lvrcolor7");
	lvrslot5();
}

sub lvrstatusbar2 {
	if ($lvrsetup == 0) {
	print colored('         Monte Carlo Roulette    ',"$lvrcolor15 on_$lvrcolor7");
	} else {
	print colored('        Roulette De Americana    ',"$lvrcolor15 on_$lvrcolor7");
	}
	print colored('       BET ',"$lvrcolor8 on_$lvrcolor7");
	lvrbet();
	print colored(' ',"$lvrcolor8 on_$lvrcolor7");
	lvrslot5();
}

sub lvrstatusbar3prison {                                            #
	print colored('          Table Minimum: 850         PRISON ',"$lvrcolor8 on_$lvrcolor7");
	lvrenprison();
	print colored(' ',"$lvrcolor8 on_$lvrcolor7");
	lvrslot5();
}

sub lvrstatusbar3 {
                                                                              #
	print colored('                                                       |',"$lvrcolor8 on_$lvrcolor7");
}

sub lvrstatusbar4 {
                                                                              #
	print colored('    P = PLAY   B = CHANGE BET  N = CHANGE NUMBERS      |',"$lvrcolor8 on_$lvrcolor7");
}

sub lvrstatusbar5 {
                                                                              #
	print colored(' C = RETURN TO CASINO MENU   ',"$lvrcolor8 on_$lvrcolor7");
	print colored('/-------------------------|',"$lvrcolor20 on_$lvrcolor21");
}

sub lvrstatusbar6 {
	print colored('   ',"$lvrcolor8 on_$lvrcolor7");
	print colored('//',"$lvrcolor20 on_$lvrcolor21");
	print colored("$lvrcomp1","$lvrcolor22 on_$lvrcolor23");
	print colored('|',"$lvrcolor20 on_$lvrcolor21");
}

sub lvrstatusbar7 {
	print colored('   ',"$lvrcolor8 on_$lvrcolor7");
	print colored('|',"$lvrcolor20 on_$lvrcolor21");
	print colored("$lvrcomp2","$lvrcolor24 on_$lvrcolor25");
	print colored('|',"$lvrcolor20 on_$lvrcolor21");
}

sub lvrstatusbar8 {
	print colored('   ',"$lvrcolor8 on_$lvrcolor7");
	print colored('|',"$lvrcolor20 on_$lvrcolor21");
	print colored("$lvrcomp3","$lvrcolor22 on_$lvrcolor23");
	print colored('|',"$lvrcolor20 on_$lvrcolor21");
}

sub lvrstatusbar9 {
	print colored('   ',"$lvrcolor8 on_$lvrcolor7");
	print colored('|',"$lvrcolor20 on_$lvrcolor21");
	print colored("$lvrcomp4","$lvrcolor24 on_$lvrcolor25");
	print colored('|',"$lvrcolor20 on_$lvrcolor21");
}

sub lvrstatusbar10 {
	print colored('   ',"$lvrcolor8 on_$lvrcolor7");
	print colored('|',"$lvrcolor20 on_$lvrcolor21");
	print colored("$lvrcomp5","$lvrcolor22 on_$lvrcolor23");
	print colored('|',"$lvrcolor20 on_$lvrcolor21");
}

sub lvrstatusbar11 {
	print colored('   ',"$lvrcolor8 on_$lvrcolor7");
	print colored('|',"$lvrcolor20 on_$lvrcolor21");
	print colored("$lvrcomp6","$lvrcolor24 on_$lvrcolor25");
	print colored('|',"$lvrcolor20 on_$lvrcolor21");
}

sub lvrstatusbar12 {
	print colored('   ',"$lvrcolor8 on_$lvrcolor7");
	print colored('|',"$lvrcolor20 on_$lvrcolor21");
	print colored("$lvrcomp7","$lvrcolor22 on_$lvrcolor23");
	print colored('|',"$lvrcolor20 on_$lvrcolor21");
}

sub lvrstatusbar13 {
	print colored('   ',"$lvrcolor8 on_$lvrcolor7");
	print colored('|',"$lvrcolor20 on_$lvrcolor21");
	print colored("$lvrcomp8","$lvrcolor24 on_$lvrcolor25");
	print colored('|',"$lvrcolor20 on_$lvrcolor21");
}

sub lvrstatusbar14 {
	print colored('   ',"$lvrcolor8 on_$lvrcolor7");
	print colored('|',"$lvrcolor20 on_$lvrcolor21");
	print colored("$lvrcomp9","$lvrcolor22 on_$lvrcolor23");
	print colored('|',"$lvrcolor20 on_$lvrcolor21");
}

sub lvrstatusbar15 {
	print colored('   ',"$lvrcolor8 on_$lvrcolor7");
	print colored('|',"$lvrcolor20 on_$lvrcolor21");
	print colored("$lvrcomp10","$lvrcolor24 on_$lvrcolor25");
	print colored('|',"$lvrcolor20 on_$lvrcolor21");
}

sub lvrstatusbar16 {
	print colored('   ',"$lvrcolor8 on_$lvrcolor7");
	print colored('|',"$lvrcolor20 on_$lvrcolor21");
	print colored("$lvrcomp11","$lvrcolor22 on_$lvrcolor23");
	print colored('|',"$lvrcolor20 on_$lvrcolor21");
}

sub lvrstatusbar17 {
	print colored('   ',"$lvrcolor8 on_$lvrcolor7");
	print colored('|',"$lvrcolor20 on_$lvrcolor21");
	print colored("$lvrcomp12","$lvrcolor24 on_$lvrcolor25");
	print colored('|',"$lvrcolor20 on_$lvrcolor21");
}

sub lvrstatusbar18 {
	print colored('   ',"$lvrcolor8 on_$lvrcolor7");
	print colored('|',"$lvrcolor20 on_$lvrcolor21");
	print colored("$lvrcomp13","$lvrcolor22 on_$lvrcolor23");
	print colored('|',"$lvrcolor20 on_$lvrcolor21");
}

sub lvrstatusbar19 {
	print colored('   ',"$lvrcolor8 on_$lvrcolor7");
	print colored('|',"$lvrcolor20 on_$lvrcolor21");
	print colored("$lvrcomp14","$lvrcolor24 on_$lvrcolor25");
	print colored('|',"$lvrcolor20 on_$lvrcolor21");
}

sub lvrstatusbar20 {
	print colored('   ',"$lvrcolor8 on_$lvrcolor7");
	print colored('|',"$lvrcolor20 on_$lvrcolor21");
	print colored("$lvrcomp15","$lvrcolor22 on_$lvrcolor23");
	print colored('|',"$lvrcolor20 on_$lvrcolor21");
}

sub lvrstatusbar21 {
	print colored('   ',"$lvrcolor8 on_$lvrcolor7");
	print colored('|',"$lvrcolor20 on_$lvrcolor21");
	print colored("$lvrcomp16","$lvrcolor24 on_$lvrcolor25");
	print colored('|',"$lvrcolor20 on_$lvrcolor21");
}

sub lvrstatusbar22 {
	print colored('   ',"$lvrcolor8 on_$lvrcolor7");
	print colored('|',"$lvrcolor20 on_$lvrcolor21");
	print colored("$lvrcomp17","$lvrcolor22 on_$lvrcolor23");
	print colored('|',"$lvrcolor20 on_$lvrcolor21");
}

sub lvrstatusbar23 {
	print colored('   ',"$lvrcolor8 on_$lvrcolor7");
	print colored('|',"$lvrcolor20 on_$lvrcolor21");
	print colored("$lvrcomp18","$lvrcolor24 on_$lvrcolor25");
	print colored('|',"$lvrcolor20 on_$lvrcolor21");
}

sub lvrstatusbar24 {
	print colored('   ',"$lvrcolor8 on_$lvrcolor7");
	print colored('|',"$lvrcolor20 on_$lvrcolor21");
	print colored("$lvrcomp19","$lvrcolor22 on_$lvrcolor23");
	print colored('|',"$lvrcolor20 on_$lvrcolor21");
}

sub lvrstatusbar25 {
	print colored('   ',"$lvrcolor8 on_$lvrcolor7");
	print colored('\\\\',"$lvrcolor20 on_$lvrcolor21");
	print colored("$lvrcomp20","$lvrcolor24 on_$lvrcolor25");
	print colored('|',"$lvrcolor20 on_$lvrcolor21");
}

sub lvrstatusbar26 {                                                                              #
	print colored('    ',"$lvrcolor8 on_$lvrcolor7");
	print colored('\-------------------------|',"$lvrcolor20 on_$lvrcolor21");
}

sub lvrstdcomp {
	if ($lvrsetup == 0) {
	$lvrcomp1 = '                         ';
	$lvrcomp2 = '  Single Numbers Pay  36X ';
	$lvrcomp3 = '                          ';
	$lvrcomp4 = '  Columns Pay          3X ';
	$lvrcomp5 = '                          ';
	$lvrcomp6 = '  Even / Odd Pays      2X ';
	$lvrcomp7 = '                          ';
		if ($lvrfuturecarlo == 1) {
		$lvrcomp8 = '  Magenta / Blue Pays  2X ';
		} else { 
		$lvrcomp8 = '  Red / Black Pays     2X ';
		}
	$lvrcomp9 = '                          ';
	$lvrcomp10 = '  Double Thirds Pay  1.5X ';
	$lvrcomp11 = '                          ';
	$lvrcomp12 = '  Triple Fourths Pay 1.3X ';
	$lvrcomp13 = '                          ';
	$lvrcomp14 = '  Groups Pay           4X ';
	$lvrcomp15 = '                          ';
	$lvrcomp16 = '  Lines Pay           12X ';
	$lvrcomp17 = '                          ';
	$lvrcomp18 = '  Powers of 2 Pay      7X ';
	$lvrcomp19 = '                          ';
	$lvrcomp20 = ' Zero Corner Pays     9X ';
	} else {
	$lvrcomp1 = '                         ';
	$lvrcomp2 = '  Single Numbers Pay  36X ';
	$lvrcomp3 = '                          ';
	$lvrcomp4 = '  Columns Pay          3X ';
	$lvrcomp5 = '                          ';
	$lvrcomp6 = '  Odds or Evens Pays   2X ';
	$lvrcomp7 = '                          ';
	$lvrcomp8 = '  Blue Pays            2X ';
	$lvrcomp9 = '                          ';
	$lvrcomp10 = '  Black Pays           2X ';
	$lvrcomp11 = '                          ';
	$lvrcomp12 = '  Double Thirds Pay  1.5X ';
	$lvrcomp13 = '                          ';
	$lvrcomp14 = '  Triple Fourths Pay 1.3X ';
	$lvrcomp15 = '                          ';
	$lvrcomp16 = '  Groups Pay           4X ';
	$lvrcomp17 = '                          ';
	$lvrcomp18 = '  Lines Pay           12X ';
	$lvrcomp19 = '                          ';
	$lvrcomp20 = ' Zero Corner Pays     9X ';
	}
}

sub lvrbetcomp {                               
	$lvrcomp1 = '                         ';
	$lvrcomp2 = '                          ';
	$lvrcomp3 = '   Enter Your Bet:        ';
	$lvrcomp4 = '                          ';
	$lvrcomp5 = '                          ';
	$lvrcomp6 = '                          ';
	$lvrcomp7 = '                          ';
	$lvrcomp8 = '                          ';
	$lvrcomp9 = '                          ';
	$lvrcomp10 = '                          ';
	$lvrcomp11 = '                          ';
	$lvrcomp12 = '                          ';
	$lvrcomp13 = '                          ';
	$lvrcomp14 = '                          ';
	$lvrcomp15 = '                          ';
	$lvrcomp16 = '                          ';
	$lvrcomp17 = '                          ';
	$lvrcomp18 = '                          ';
	$lvrcomp19 = '                          ';
	$lvrcomp20 = '                         ';
}

sub lvrnbrcomp {
	$lvrcomp1 = '  Choose Numbers:        ';                               
	$lvrcomp2 = '*Enter A Number To Play # ';
	$lvrcomp3 = '*Enter C1, C2, or C3 To   ';
	$lvrcomp4 = '  Play Column 1, 2, or 3  ';
	$lvrcomp5 = '*Enter T1, T2, or T3 To   ';
	$lvrcomp6 = '  Play 2/3 Of The Wheel   ';
	$lvrcomp7 = '*Enter F1..F4 To Play 3/4 ';
	$lvrcomp8 = '*Enter EVEN To Play Even  ';
	$lvrcomp9 = '*Enter ODD To Play Odd    ';
	if ($lvrsetup == 0) {
		if ($lvrfuturecarlo == 1) {
		$lvrcomp10 = '*Enter MAGENTA To Play Mag';
		$lvrcomp11 = '*Enter BLUE To Play Blue  ';
		} else {
		$lvrcomp10 = '*Enter RED To Play Red    ';
		$lvrcomp11 = '*Enter BLACK To Play Black';
		}
	} else {
	$lvrcomp10 = '*Enter BLUE To Play Blue  ';
	$lvrcomp11 = '*Enter BLACK To Play Black';
	}
	$lvrcomp12 = '*Enter LOWER18 To Play Top';
	$lvrcomp13 = '*Enter UPPER18 To Play Bot';
	$lvrcomp14 = '*Enter G1..G4  ToPlayGroup';
	$lvrcomp15 = '*Enter L1..L12 ToPlay Line';
	$lvrcomp16 = '*Enter V, O, or T  To Play';
	$lvrcomp17 = '  Voisins, Orphelins, Tier';
	if ($lvrsetup == 0) {
	$lvrcomp18 = '*Enter P2 To Play Powers  ';
	$lvrcomp19 = '  Of Two                  ';
	$lvrcomp20 = '*Enter ZC To Play ZeroCnr';
	} else {
	$lvrcomp18 = '*Enter ZC To Play ZeroCnr ';
	$lvrcomp19 = '                          ';
	$lvrcomp20 = '                         ';
	}	
}

sub lvrtotal {
	sep; 
	if ($money > 9999999999) {
	print colored(sprintf("%.4e", $money),"$lvrcolor13 on_$lvrcolor14");
	} elsif ($money >= 1000000000) {
	print colored("$money","$lvrcolor13 on_$lvrcolor14");
	} elsif ($money >= 100000000) {
	print colored(" $money","$lvrcolor13 on_$lvrcolor14");
	} elsif ($money >= 10000000) {
	print colored("  $money","$lvrcolor13 on_$lvrcolor14");
	} elsif ($money >= 1000000) {
	print colored("   $money","$lvrcolor13 on_$lvrcolor14");
	} elsif ($money >= 100000) {
	print colored("    $money","$lvrcolor13 on_$lvrcolor14");
	} elsif ($money >= 10000) {
	print colored("     $money","$lvrcolor13 on_$lvrcolor14");
	} elsif ($money >= 1000) {
	print colored("      $money","$lvrcolor13 on_$lvrcolor14");
	} elsif ($money >= 100) {
	print colored("       $money","$lvrcolor13 on_$lvrcolor14");
	} elsif ($money >= 10) {
	print colored("        $money","$lvrcolor13 on_$lvrcolor14");
	} elsif ($money >= 1) {
	print colored("         $money","$lvrcolor13 on_$lvrcolor14");
	} else {
	print colored("         $money","$lvrcolor13 on_$lvrcolor14");
	}
	sep; 
}

sub lvrwinnings {
	sep;
	if ($lvrmoney > 9999999999) {
	print colored(sprintf("%.4e", $lvrmoney),"$lvrcolor13 on_$lvrcolor14");
	} elsif ($lvrmoney >= 1000000000) {
	print colored("$lvrmoney","$lvrcolor13 on_$lvrcolor14");
	} elsif ($lvrmoney >= 100000000) {
	print colored(" $lvrmoney","$lvrcolor13 on_$lvrcolor14");
	} elsif ($lvrmoney >= 10000000) {
	print colored("  $lvrmoney","$lvrcolor13 on_$lvrcolor14");
	} elsif ($lvrmoney >= 1000000) {
	print colored("   $lvrmoney","$lvrcolor13 on_$lvrcolor14");
	} elsif ($lvrmoney >= 100000) {
	print colored("    $lvrmoney","$lvrcolor13 on_$lvrcolor14");
	} elsif ($lvrmoney >= 10000) {
	print colored("     $lvrmoney","$lvrcolor13 on_$lvrcolor14");
	} elsif ($lvrmoney >= 1000) {
	print colored("      $lvrmoney","$lvrcolor13 on_$lvrcolor14");
	} elsif ($lvrmoney >= 100) {
	print colored("       $lvrmoney","$lvrcolor13 on_$lvrcolor14");
	} elsif ($lvrmoney >= 10) {
	print colored("        $lvrmoney","$lvrcolor13 on_$lvrcolor14");
	} elsif ($lvrmoney >= 1) {
	print colored("         $lvrmoney","$lvrcolor13 on_$lvrcolor14");
	} else {
	print colored("         $lvrmoney","$lvrcolor13 on_$lvrcolor14");
	}
	sep; 
}

sub lvrenprison {
	sep;
	if ($lvrimprison > 9999999999) {
	print colored(sprintf("%.4e", $lvrimprison),"$lvrcolor13 on_$lvrcolor14");
	} elsif ($lvrimprison >= 1000000000) {
	print colored("$lvrimprison","$lvrcolor13 on_$lvrcolor14");
	} elsif ($lvrimprison >= 100000000) {
	print colored(" $lvrimprison","$lvrcolor13 on_$lvrcolor14");
	} elsif ($lvrimprison >= 10000000) {
	print colored("  $lvrimprison","$lvrcolor13 on_$lvrcolor14");
	} elsif ($lvrimprison >= 1000000) {
	print colored("   $lvrimprison","$lvrcolor13 on_$lvrcolor14");
	} elsif ($lvrimprison >= 100000) {
	print colored("    $lvrimprison","$lvrcolor13 on_$lvrcolor14");
	} elsif ($lvrimprison >= 10000) {
	print colored("     $lvrimprison","$lvrcolor13 on_$lvrcolor14");
	} elsif ($lvrimprison >= 1000) {
	print colored("      $lvrimprison","$lvrcolor13 on_$lvrcolor14");
	} elsif ($lvrimprison >= 100) {
	print colored("       $lvrimprison","$lvrcolor13 on_$lvrcolor14");
	} elsif ($lvrimprison >= 10) {
	print colored("        $lvrimprison","$lvrcolor13 on_$lvrcolor14");
	} elsif ($lvrimprison >= 1) {
	print colored("         $lvrimprison","$lvrcolor13 on_$lvrcolor14");
	} else {
	print colored("         $lvrimprison","$lvrcolor13 on_$lvrcolor14");
	}
	sep; 
}

sub lvrbet {
	sep;
	if ($lvrbet > 9999999999) {
	print colored(sprintf("%.4e", $lvrbet),"$lvrcolor13 on_$lvrcolor14");
	} elsif ($lvrbet >= 1000000000) {
	print colored("$lvrbet","$lvrcolor13 on_$lvrcolor14");
	} elsif ($lvrbet >= 100000000) {
	print colored(" $lvrbet","$lvrcolor13 on_$lvrcolor14");
	} elsif ($lvrbet >= 10000000) {
	print colored("  $lvrbet","$lvrcolor13 on_$lvrcolor14");
	} elsif ($lvrbet >= 1000000) {
	print colored("   $lvrbet","$lvrcolor13 on_$lvrcolor14");
	} elsif ($lvrbet >= 100000) {
	print colored("    $lvrbet","$lvrcolor13 on_$lvrcolor14");
	} elsif ($lvrbet >= 10000) {
	print colored("     $lvrbet","$lvrcolor13 on_$lvrcolor14");
	} elsif ($lvrbet >= 1000) {
	print colored("      $lvrbet","$lvrcolor13 on_$lvrcolor14");
	} elsif ($lvrbet >= 100) {
	print colored("       $lvrbet","$lvrcolor13 on_$lvrcolor14");
	} elsif ($lvrbet >= 10) {
	print colored("        $lvrbet","$lvrcolor13 on_$lvrcolor14");
	} elsif ($lvrbet >= 1) {
	print colored("         $lvrbet","$lvrcolor13 on_$lvrcolor14");
	} else {
	print colored("         $lvrbet","$lvrcolor13 on_$lvrcolor14");
	}
	sep; 
}

sub lvrspace1 {
	print colored('      ',"$lvrcolor8 on_$lvrcolor7");
}

sub lvrspace1rt1 {
	print colored('   /-\\',"$lvrcolor8 on_$lvrcolor7");
}

sub lvrspace1rt2 {
	print colored('  |',"$lvrcolor8 on_$lvrcolor7");
	if ($lvrbVOIp == 1) {
		print colored('V',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored('V',"$lvrcolor16 on_$lvrcolor17");
	}
	print colored('  ',"$lvrcolor8 on_$lvrcolor7");
}

sub lvrspace1rt3 {
	print colored('  |',"$lvrcolor8 on_$lvrcolor7");
	if ($lvrbVOIp == 1) {
		print colored('O',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored('O',"$lvrcolor16 on_$lvrcolor17");
	}
	print colored('  ',"$lvrcolor8 on_$lvrcolor7");
}

sub lvrspace1rt4 {
	print colored('  |',"$lvrcolor8 on_$lvrcolor7");
	if ($lvrbVOIp == 1) {
		print colored('I',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored('I',"$lvrcolor16 on_$lvrcolor17");
	}
	print colored('  ',"$lvrcolor8 on_$lvrcolor7");
}

sub lvrspace1rt5 {
	print colored('  |',"$lvrcolor8 on_$lvrcolor7");
	if ($lvrbVOIp == 1) {
		print colored('S',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored('S',"$lvrcolor16 on_$lvrcolor17");
	}
	print colored('  ',"$lvrcolor8 on_$lvrcolor7");
}

sub lvrspace1rt6 {
	print colored('  |',"$lvrcolor8 on_$lvrcolor7");
	if ($lvrbVOIp == 1) {
		print colored('I',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored('I',"$lvrcolor16 on_$lvrcolor17");
	}
	print colored('| ',"$lvrcolor8 on_$lvrcolor7");
}

sub lvrspace1rt7 {
	print colored('  |',"$lvrcolor8 on_$lvrcolor7");
	if ($lvrbVOIp == 1) {
		print colored('N',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored('N',"$lvrcolor16 on_$lvrcolor17");
	}
	print colored('| ',"$lvrcolor8 on_$lvrcolor7");
}

sub lvrspace1rt8 {
	print colored('  |',"$lvrcolor8 on_$lvrcolor7");
	if ($lvrbVOIp == 1) {
		print colored('S',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored('S',"$lvrcolor16 on_$lvrcolor17");
	}
	print colored('|',"$lvrcolor8 on_$lvrcolor7");
	if ($lvrbORPp == 1) {
		print colored('O',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored('O',"$lvrcolor16 on_$lvrcolor17");
	}
}

sub lvrspace1rt9 {
	print colored('  | |',"$lvrcolor8 on_$lvrcolor7");
	if ($lvrbORPp == 1) {
		print colored('R',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored('R',"$lvrcolor16 on_$lvrcolor17");
	}
}

sub lvrspace1rt10 {
	print colored('  | |',"$lvrcolor8 on_$lvrcolor7");
	if ($lvrbORPp == 1) {
		print colored('P',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored('P',"$lvrcolor16 on_$lvrcolor17");
	}
}

sub lvrspace1rt11 {
	print colored('  | |',"$lvrcolor8 on_$lvrcolor7");
	if ($lvrbORPp == 1) {
		print colored('H',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored('H',"$lvrcolor16 on_$lvrcolor17");
	}
}

sub lvrspace1rt12 {
	print colored('  | |',"$lvrcolor8 on_$lvrcolor7");
	if ($lvrbORPp == 1) {
		print colored('E',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored('E',"$lvrcolor16 on_$lvrcolor17");
	}
}

sub lvrspace1rt13 {
	print colored('  | |',"$lvrcolor8 on_$lvrcolor7");
	if ($lvrbORPp == 1) {
		print colored('L',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored('L',"$lvrcolor16 on_$lvrcolor17");
	}
}

sub lvrspace1rt14 {
	print colored('  | |',"$lvrcolor8 on_$lvrcolor7");
	if ($lvrbORPp == 1) {
		print colored('I',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored('I',"$lvrcolor16 on_$lvrcolor17");
	}
}

sub lvrspace1rt15 {
	print colored('  | |',"$lvrcolor8 on_$lvrcolor7");
	if ($lvrbORPp == 1) {
		print colored('N',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored('N',"$lvrcolor16 on_$lvrcolor17");
	}
}

sub lvrspace1rt16 {
	print colored('  |',"$lvrcolor8 on_$lvrcolor7");
	if ($lvrbTIEp == 1) {
		print colored('T',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored('T',"$lvrcolor16 on_$lvrcolor17");
	}
	print colored('|',"$lvrcolor8 on_$lvrcolor7");
	if ($lvrbORPp == 1) {
		print colored('S',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored('S',"$lvrcolor16 on_$lvrcolor17");
	}
}

sub lvrspace1rt17 {
	print colored('  |',"$lvrcolor8 on_$lvrcolor7");
	if ($lvrbTIEp == 1) {
		print colored('I',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored('I',"$lvrcolor16 on_$lvrcolor17");
	}
	print colored('  ',"$lvrcolor8 on_$lvrcolor7");
}

sub lvrspace1rt18 {
	print colored('  |',"$lvrcolor8 on_$lvrcolor7");
	if ($lvrbTIEp == 1) {
		print colored('E',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored('E',"$lvrcolor16 on_$lvrcolor17");
	}
	print colored('  ',"$lvrcolor8 on_$lvrcolor7");
}

sub lvrspace1rt19 {
	print colored('  |',"$lvrcolor8 on_$lvrcolor7");
	if ($lvrbTIEp == 1) {
		print colored('R',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored('R',"$lvrcolor16 on_$lvrcolor17");
	}
	print colored('  ',"$lvrcolor8 on_$lvrcolor7");
}

sub lvrspace1rt20 {
	print colored('  |',"$lvrcolor8 on_$lvrcolor7");
	if ($lvrbTIEp == 1) {
		print colored('S',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored('S',"$lvrcolor16 on_$lvrcolor17");
	}
	print colored('  ',"$lvrcolor8 on_$lvrcolor7");
}

sub lvrspace1rt21 {
	print colored('   \\-/',"$lvrcolor8 on_$lvrcolor7");
}

sub lvrb0000 {
	print colored('\\-----------------/',"$lvrcolor8 on_$lvrcolor7");
}

sub lvrb000 {
	print colored('/-----------------\\',"$lvrcolor8 on_$lvrcolor7");
}

sub lvrb00 {
	if ($lvrsetup == 1) {
		#Roulette De Americana
		lvrslot5();
		if ($lvrb0p == 1) {
			print colored('        0        ',"$lvrcolor18 on_$red");	
		} else {
			print colored('        0        ',"$boldred on_$lvrcolor17");
		}
		lvrslot5();
	} else {
		#Monte Carlo Roulette
		lvrslot5();
		if ($lvrb0p == 1) {
			print colored('        0        ',"$lvrcolor18 on_$lvrcolor19");	
		} else {
			print colored('        0        ',"$lvrcolor16 on_$lvrcolor17");
		}
		lvrslot5();
	}
}

sub lvrb00000 {
	lvrslot5();
	if ($lvrbRp == 1) {
		print colored("$lvrredvar","$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored("$lvrredvar","$lvrcolor16 on_$lvrcolor17");
	}
	lvrslot5();
	if ($lvrbBp == 1) {
		print colored("$lvrblkvar","$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored("$lvrblkvar","$lvrcolor16 on_$lvrcolor17");
	}
	lvrslot5();
}

sub lvrb0 {
	print colored('|-----------------|',"$lvrcolor8 on_$lvrcolor7");
}

sub lvrb1 {
	lvrslot5();
	if ($lvrb1p == 1) {
		print colored('  1  ',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored('  1  ',"$lvrcolor16 on_$lvrcolor17");
	}
	lvrslot5();
	if ($lvrb2p == 1) {
		print colored('  2  ',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored('  2  ',"$lvrcolor16 on_$lvrcolor17");
	}
	lvrslot5();
	if ($lvrb3p == 1) {
		print colored('  3  ',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored('  3  ',"$lvrcolor16 on_$lvrcolor17");
	}
	lvrslot5();	
}

sub lvrb2 {
	lvrslot5();
	if ($lvrb4p == 1) {
		print colored('  4  ',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored('  4  ',"$lvrcolor16 on_$lvrcolor17");
	}
	lvrslot5();
	if ($lvrb5p == 1) {
		print colored('  5  ',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored('  5  ',"$lvrcolor16 on_$lvrcolor17");
	}
	lvrslot5();
	if ($lvrb6p == 1) {
		print colored('  6  ',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored('  6  ',"$lvrcolor16 on_$lvrcolor17");
	}
	lvrslot5();	
}

sub lvrb3 {
	lvrslot5();
	if ($lvrb7p == 1) {
		print colored('  7  ',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored('  7  ',"$lvrcolor16 on_$lvrcolor17");
	}
	lvrslot5();
	if ($lvrb8p == 1) {
		print colored('  8  ',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored('  8  ',"$lvrcolor16 on_$lvrcolor17");
	}
	lvrslot5();
	if ($lvrb9p == 1) {
		print colored('  9  ',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored('  9  ',"$lvrcolor16 on_$lvrcolor17");
	}
	lvrslot5();	
}

sub lvrb4 {
	lvrslot5();
	if ($lvrb10p == 1) {
		print colored(' 1 0 ',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored(' 1 0 ',"$lvrcolor16 on_$lvrcolor17");
	}
	lvrslot5();
	if ($lvrb11p == 1) {
		print colored(' 1 1 ',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored(' 1 1 ',"$lvrcolor16 on_$lvrcolor17");
	}
	lvrslot5();
	if ($lvrb12p == 1) {
		print colored(' 1 2 ',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored(' 1 2 ',"$lvrcolor16 on_$lvrcolor17");
	}
	lvrslot5();	
}

sub lvrb5 {
	lvrslot5();
	if ($lvrb13p == 1) {
		print colored(' 1 3 ',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored(' 1 3 ',"$lvrcolor16 on_$lvrcolor17");
	}
	lvrslot5();
	if ($lvrb14p == 1) {
		print colored(' 1 4 ',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored(' 1 4 ',"$lvrcolor16 on_$lvrcolor17");
	}
	lvrslot5();
	if ($lvrb15p == 1) {
		print colored(' 1 5 ',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored(' 1 5 ',"$lvrcolor16 on_$lvrcolor17");
	}
	lvrslot5();	
}

sub lvrb6 {
	lvrslot5();
	if ($lvrb16p == 1) {
		print colored(' 1 6 ',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored(' 1 6 ',"$lvrcolor16 on_$lvrcolor17");
	}
	lvrslot5();
	if ($lvrb17p == 1) {
		print colored(' 1 7 ',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored(' 1 7 ',"$lvrcolor16 on_$lvrcolor17");
	}
	lvrslot5();
	if ($lvrb18p == 1) {
		print colored(' 1 8 ',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored(' 1 8 ',"$lvrcolor16 on_$lvrcolor17");
	}
	lvrslot5();	
}

sub lvrb7 {
	lvrslot5();
	if ($lvrb19p == 1) {
		print colored(' 1 9 ',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored(' 1 9 ',"$lvrcolor16 on_$lvrcolor17");
	}
	lvrslot5();
	if ($lvrb20p == 1) {
		print colored(' 2 0 ',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored(' 2 0 ',"$lvrcolor16 on_$lvrcolor17");
	}
	lvrslot5();
	if ($lvrb21p == 1) {
		print colored(' 2 1 ',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored(' 2 1 ',"$lvrcolor16 on_$lvrcolor17");
	}
	lvrslot5();	
}

sub lvrb8 {
	lvrslot5();
	if ($lvrb22p == 1) {
		print colored(' 2 2 ',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored(' 2 2 ',"$lvrcolor16 on_$lvrcolor17");
	}
	lvrslot5();
	if ($lvrb23p == 1) {
		print colored(' 2 3 ',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored(' 2 3 ',"$lvrcolor16 on_$lvrcolor17");
	}
	lvrslot5();
	if ($lvrb24p == 1) {
		print colored(' 2 4 ',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored(' 2 4 ',"$lvrcolor16 on_$lvrcolor17");
	}
	lvrslot5();	
}

sub lvrb9 {
	lvrslot5();
	if ($lvrb25p == 1) {
		print colored(' 2 5 ',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored(' 2 5 ',"$lvrcolor16 on_$lvrcolor17");
	}
	lvrslot5();
	if ($lvrb26p == 1) {
		print colored(' 2 6 ',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored(' 2 6 ',"$lvrcolor16 on_$lvrcolor17");
	}
	lvrslot5();
	if ($lvrb27p == 1) {
		print colored(' 2 7 ',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored(' 2 7 ',"$lvrcolor16 on_$lvrcolor17");
	}
	lvrslot5();	
}

sub lvrb10 {
	lvrslot5();
	if ($lvrb28p == 1) {
		print colored(' 2 8 ',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored(' 2 8 ',"$lvrcolor16 on_$lvrcolor17");
	}
	lvrslot5();
	if ($lvrb29p == 1) {
		print colored(' 2 9 ',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored(' 2 9 ',"$lvrcolor16 on_$lvrcolor17");
	}
	lvrslot5();
	if ($lvrb30p == 1) {
		print colored(' 3 0 ',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored(' 3 0 ',"$lvrcolor16 on_$lvrcolor17");
	}
	lvrslot5();	
}

sub lvrb11 {
	lvrslot5();
	if ($lvrb31p == 1) {
		print colored(' 3 1 ',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored(' 3 1 ',"$lvrcolor16 on_$lvrcolor17");
	}
	lvrslot5();
	if ($lvrb32p == 1) {
		print colored(' 3 2 ',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored(' 3 2 ',"$lvrcolor16 on_$lvrcolor17");
	}
	lvrslot5();
	if ($lvrb33p == 1) {
		print colored(' 3 3 ',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored(' 3 3 ',"$lvrcolor16 on_$lvrcolor17");
	}
	lvrslot5();	
}

sub lvrb12 {
	lvrslot5();
	if ($lvrb34p == 1) {
		print colored(' 3 4 ',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored(' 3 4 ',"$lvrcolor16 on_$lvrcolor17");
	}
	lvrslot5();
	if ($lvrb35p == 1) {
		print colored(' 3 5 ',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored(' 3 5 ',"$lvrcolor16 on_$lvrcolor17");
	}
	lvrslot5();
	if ($lvrb36p == 1) {
		print colored(' 3 6 ',"$lvrcolor18 on_$lvrcolor19");	
	} else {
		print colored(' 3 6 ',"$lvrcolor16 on_$lvrcolor17");
	}
	lvrslot5();	
}


################################################################################################################################
## GENRE: Roulette
## NAME: Real Vegas Roulette
## AUTHOR: MikeeUSA

sub rllvrmainspin1 {
	rllvrreset();
	rllvrcolorsg();
	
	if ($animate == 1) {
		$rllvrreelspin = 2;
		
		rllvrstdcomp();
		rllvrspin();
		rllvrwheel();
		rllvrprintmain();
		p4pause();
		newlines();
		
		rllvrstdcomp();
		rllvrspin();
		rllvrwheel();
		rllvrprintmain();
		p4pause();
		newlines();
		
		rllvrstdcomp();
		rllvrspin();
		rllvrwheel();
		rllvrprintmain();
		p4pause();
		newlines();
		
		rllvrstdcomp();
		rllvrspin();
		rllvrwheel();
		rllvrprintmain();
		p4pause();
		newlines();
		
		rllvrstdcomp();
		rllvrspin();
		rllvrwheel();
		rllvrprintmain();
		p4pause();
		newlines();
		
		rllvrstdcomp();
		rllvrspin();
		rllvrwheel();
		rllvrprintmain();
		p4pause();
		newlines();
		
		rllvrstdcomp();
		rllvrspin();
		rllvrwheel();
		rllvrprintmain();
		p4pause();
		newlines();
		
		rllvrstdcomp();
		rllvrspin();
		rllvrwheel();
		rllvrprintmain();
		p4pause();
		newlines();
		
		
		
		rllvrstdcomp();
		rllvrspin();
		rllvrwheel();
		rllvrprintmain();
		p7pause();
		newlines();
		
		rllvrstdcomp();
		rllvrspin();
		rllvrwheel();
		rllvrprintmain();
		p7pause();
		newlines();
		
		rllvrstdcomp();
		rllvrspin();
		rllvrwheel();
		rllvrprintmain();
		p7pause();
		newlines();
		$rllvrreelspin = 1;
		rllvrstdcomp();
		rllvrspin();
		rllvrwheel();
		rllvrprintmain();
		p7pause();
		newlines();
		
		rllvrstdcomp();
		rllvrspin();
		rllvrwheel();
		rllvrprintmain();
		p7pause();
		newlines();
		
		rllvrstdcomp();
		rllvrspin();
		rllvrwheel();
		rllvrprintmain();
		p7pause();
		newlines();
		
		rllvrstdcomp();
		rllvrspin();
		rllvrwheel();
		rllvrprintmain();
		p7pause();
		newlines();
		
		
		
		rllvrstdcomp();
		rllvrspin();
		rllvrwheel();
		rllvrprintmain();
		tinypause();
		newlines();
		
		rllvrstdcomp();
		rllvrspin();
		rllvrwheel();
		rllvrprintmain();
		tinypause();
		newlines();
		
		rllvrstdcomp();
		rllvrspin();
		rllvrwheel();
		rllvrprintmain();
		tinypause();
		newlines();
		
		
				
		rllvrstdcomp();
		rllvrspin();
		rllvrwheel();
		rllvrprintmain();
		smallpause();
		newlines();
		
		
	}
	$rllvrreelspin = 0;
	rllvrstdcomp();
	rllvrspin();
	rllvrwheel();
	rllvraddmoney();
	rllvrprintmain();
	ptracker();
	rllvrstdin1();
}

sub rllvrmainspin2 {
	rllvrreset();
	rllvrcolorsg();
	rllvrstdcomp();
	rllvrwheel();
	rllvrprintmain();
	rllvrstdin1();
}

sub rllvrnbrspin3 {
	rllvrreset();
	rllvrcolorsg();
	rllvrnbrcomp();
	rllvrwheel();
	rllvrprintmain();
	$rllvrstart2 = <STDIN>;
	chomp($rllvrstart2);
		rllvrnbrreset();
		if ($rllvrstart2 eq '00') {
			$rllvrb00p = 1;
		} elsif ($rllvrstart2 eq '0') {
			$rllvrb0p = 1;
		} elsif ($rllvrstart2 eq '1') {
			$rllvrb1p = 1;
		} elsif ($rllvrstart2 eq '2') {
			$rllvrb2p = 1;
		} elsif ($rllvrstart2 eq '3') {
			$rllvrb3p = 1;
		} elsif ($rllvrstart2 eq '4') {
			$rllvrb4p = 1;
		} elsif ($rllvrstart2 eq '5') {
			$rllvrb5p = 1;
		} elsif ($rllvrstart2 eq '6') {
			$rllvrb6p = 1;
		} elsif ($rllvrstart2 eq '7') {
			$rllvrb7p = 1;
		} elsif ($rllvrstart2 eq '8') {
			$rllvrb8p = 1;
		} elsif ($rllvrstart2 eq '9') {
			$rllvrb9p = 1;
		} elsif ($rllvrstart2 eq '10') {
			$rllvrb10p = 1;
		} elsif ($rllvrstart2 eq '11') {
			$rllvrb11p = 1;
		} elsif ($rllvrstart2 eq '12') {
			$rllvrb12p = 1;
		} elsif ($rllvrstart2 eq '13') {
			$rllvrb13p = 1;
		} elsif ($rllvrstart2 eq '14') {
			$rllvrb14p = 1;
		} elsif ($rllvrstart2 eq '15') {
			$rllvrb15p = 1;
		} elsif ($rllvrstart2 eq '16') {
			$rllvrb16p = 1;
		} elsif ($rllvrstart2 eq '17') {
			$rllvrb17p = 1;
		} elsif ($rllvrstart2 eq '18') {
			$rllvrb18p = 1;
		} elsif ($rllvrstart2 eq '19') {
			$rllvrb19p = 1;
		} elsif ($rllvrstart2 eq '20') {
			$rllvrb20p = 1;
		} elsif ($rllvrstart2 eq '21') {
			$rllvrb21p = 1;
		} elsif ($rllvrstart2 eq '22') {
			$rllvrb22p = 1;
		} elsif ($rllvrstart2 eq '23') {
			$rllvrb23p = 1;
		} elsif ($rllvrstart2 eq '24') {
			$rllvrb24p = 1;
		} elsif ($rllvrstart2 eq '25') {
			$rllvrb25p = 1;
		} elsif ($rllvrstart2 eq '26') {
			$rllvrb26p = 1;
		} elsif ($rllvrstart2 eq '27') {
			$rllvrb27p = 1;
		} elsif ($rllvrstart2 eq '28') {
			$rllvrb28p = 1;
		} elsif ($rllvrstart2 eq '29') {
			$rllvrb29p = 1;
		} elsif ($rllvrstart2 eq '30') {
			$rllvrb30p = 1;
		} elsif ($rllvrstart2 eq '31') {
			$rllvrb31p = 1;
		} elsif ($rllvrstart2 eq '32') {
			$rllvrb32p = 1;
		} elsif ($rllvrstart2 eq '33') {
			$rllvrb33p = 1;
		} elsif ($rllvrstart2 eq '34') {
			$rllvrb34p = 1;
		} elsif ($rllvrstart2 eq '35') {
			$rllvrb35p = 1;
		} elsif ($rllvrstart2 eq '36') {
			$rllvrb36p = 1;
		} elsif (($rllvrstart2 eq 'even') or ($rllvrstart2 eq 'EVEN')) {
			$rllvrstart2 = 'EVEN';
			$rllvrb2p = 1;	
			$rllvrb4p = 1;
			$rllvrb6p = 1;
			$rllvrb8p = 1;	
			$rllvrb10p = 1;
			$rllvrb12p = 1;	
			$rllvrb14p = 1;
			$rllvrb16p = 1;
			$rllvrb18p = 1;	
			$rllvrb20p = 1;	
			$rllvrb22p = 1;	
			$rllvrb24p = 1;
			$rllvrb26p = 1;
			$rllvrb28p = 1;	
			$rllvrb30p = 1;
			$rllvrb32p = 1;	
			$rllvrb34p = 1;
			$rllvrb36p = 1;
		} elsif (($rllvrstart2 eq 'odd') or ($rllvrstart2 eq 'ODD')) {
			$rllvrstart2 = 'ODD';
			$rllvrb1p = 1;	
			$rllvrb3p = 1;
			$rllvrb5p = 1;
			$rllvrb7p = 1;	
			$rllvrb9p = 1;
			$rllvrb11p = 1;	
			$rllvrb13p = 1;
			$rllvrb15p = 1;
			$rllvrb17p = 1;	
			$rllvrb19p = 1;	
			$rllvrb21p = 1;	
			$rllvrb23p = 1;
			$rllvrb25p = 1;
			$rllvrb27p = 1;	
			$rllvrb29p = 1;
			$rllvrb31p = 1;	
			$rllvrb33p = 1;
			$rllvrb35p = 1;
		} elsif (($rllvrstart2 eq 'lower18') or ($rllvrstart2 eq 'LOWER18')) {
			$rllvrstart2 = 'LOWER18';
			$rllvrb1p = 1;	
			$rllvrb2p = 1;
			$rllvrb3p = 1;
			$rllvrb4p = 1;	
			$rllvrb5p = 1;
			$rllvrb6p = 1;	
			$rllvrb7p = 1;
			$rllvrb8p = 1;
			$rllvrb9p = 1;	
			$rllvrb10p = 1;	
			$rllvrb11p = 1;	
			$rllvrb12p = 1;
			$rllvrb13p = 1;
			$rllvrb14p = 1;	
			$rllvrb15p = 1;
			$rllvrb16p = 1;	
			$rllvrb17p = 1;
			$rllvrb18p = 1;
		} elsif (($rllvrstart2 eq 'upper18') or ($rllvrstart2 eq 'UPPER18')) {
			$rllvrstart2 = 'UPPER18';
			$rllvrb19p = 1;	
			$rllvrb20p = 1;
			$rllvrb21p = 1;
			$rllvrb22p = 1;	
			$rllvrb23p = 1;
			$rllvrb24p = 1;	
			$rllvrb25p = 1;
			$rllvrb26p = 1;
			$rllvrb27p = 1;	
			$rllvrb28p = 1;	
			$rllvrb29p = 1;	
			$rllvrb30p = 1;
			$rllvrb31p = 1;
			$rllvrb32p = 1;	
			$rllvrb33p = 1;
			$rllvrb34p = 1;	
			$rllvrb35p = 1;
			$rllvrb36p = 1;	
		} elsif (($rllvrstart2 eq 'c1') or ($rllvrstart2 eq 'C1')) {
			$rllvrstart2 = 'C1';
			$rllvrb1p = 1;	
			$rllvrb4p = 1;
			$rllvrb7p = 1;
			$rllvrb10p = 1;	
			$rllvrb13p = 1;
			$rllvrb16p = 1;	
			$rllvrb19p = 1;
			$rllvrb22p = 1;
			$rllvrb25p = 1;	
			$rllvrb28p = 1;	
			$rllvrb31p = 1;	
			$rllvrb34p = 1;
		} elsif (($rllvrstart2 eq 'c2') or ($rllvrstart2 eq 'C2')) {
			$rllvrstart2 = 'C2';
			$rllvrb2p = 1;	
			$rllvrb5p = 1;
			$rllvrb8p = 1;
			$rllvrb11p = 1;	
			$rllvrb14p = 1;
			$rllvrb17p = 1;	
			$rllvrb20p = 1;
			$rllvrb23p = 1;
			$rllvrb26p = 1;	
			$rllvrb29p = 1;	
			$rllvrb32p = 1;	
			$rllvrb35p = 1;
		} elsif (($rllvrstart2 eq 'c3') or ($rllvrstart2 eq 'C3')) {
			$rllvrstart2 = 'C3';
			$rllvrb3p = 1;	
			$rllvrb6p = 1;
			$rllvrb9p = 1;
			$rllvrb12p = 1;	
			$rllvrb15p = 1;
			$rllvrb18p = 1;	
			$rllvrb21p = 1;
			$rllvrb24p = 1;
			$rllvrb27p = 1;	
			$rllvrb30p = 1;	
			$rllvrb33p = 1;	
			$rllvrb36p = 1;
		} elsif (($rllvrstart2 eq 'g1') or ($rllvrstart2 eq 'G1')) {
			$rllvrstart2 = 'G1';
			$rllvrb1p = 1;	
			$rllvrb2p = 1;
			$rllvrb3p = 1;
			$rllvrb4p = 1;	
			$rllvrb5p = 1;
			$rllvrb6p = 1;	
			$rllvrb7p = 1;
			$rllvrb8p = 1;
			$rllvrb9p = 1;	
		} elsif (($rllvrstart2 eq 'g2') or ($rllvrstart2 eq 'G2')) {
			$rllvrstart2 = 'G2';
			$rllvrb10p = 1;	
			$rllvrb11p = 1;
			$rllvrb12p = 1;
			$rllvrb13p = 1;	
			$rllvrb14p = 1;
			$rllvrb15p = 1;	
			$rllvrb16p = 1;
			$rllvrb17p = 1;
			$rllvrb18p = 1;
		} elsif (($rllvrstart2 eq 'g3') or ($rllvrstart2 eq 'G3')) {
			$rllvrstart2 = 'G3';
			$rllvrb19p = 1;	
			$rllvrb20p = 1;
			$rllvrb21p = 1;
			$rllvrb22p = 1;	
			$rllvrb23p = 1;
			$rllvrb24p = 1;	
			$rllvrb25p = 1;
			$rllvrb26p = 1;
			$rllvrb27p = 1;
		} elsif (($rllvrstart2 eq 'g4') or ($rllvrstart2 eq 'G4')) {
			$rllvrstart2 = 'G4';
			$rllvrb28p = 1;	
			$rllvrb29p = 1;
			$rllvrb30p = 1;
			$rllvrb31p = 1;	
			$rllvrb32p = 1;
			$rllvrb33p = 1;	
			$rllvrb34p = 1;
			$rllvrb35p = 1;
			$rllvrb36p = 1;	
		} elsif (($rllvrstart2 eq 'l1') or ($rllvrstart2 eq 'L1')) {
			$rllvrstart2 = 'L1';
			$rllvrb1p = 1;	
			$rllvrb2p = 1;
			$rllvrb3p = 1;
		} elsif (($rllvrstart2 eq 'l2') or ($rllvrstart2 eq 'L2')) {
			$rllvrstart2 = 'L2';
			$rllvrb4p = 1;	
			$rllvrb5p = 1;
			$rllvrb6p = 1;
		} elsif (($rllvrstart2 eq 'l3') or ($rllvrstart2 eq 'L3')) {
			$rllvrstart2 = 'L3';
			$rllvrb7p = 1;	
			$rllvrb8p = 1;
			$rllvrb9p = 1;
		} elsif (($rllvrstart2 eq 'l4') or ($rllvrstart2 eq 'L4')) {
			$rllvrstart2 = 'L4';
			$rllvrb10p = 1;	
			$rllvrb11p = 1;
			$rllvrb12p = 1;
		} elsif (($rllvrstart2 eq 'l5') or ($rllvrstart2 eq 'L5')) {
			$rllvrstart2 = 'L5';
			$rllvrb13p = 1;	
			$rllvrb14p = 1;
			$rllvrb15p = 1;
		} elsif (($rllvrstart2 eq 'l6') or ($rllvrstart2 eq 'L6')) {
			$rllvrstart2 = 'L6';
			$rllvrb16p = 1;	
			$rllvrb17p = 1;
			$rllvrb18p = 1;
		} elsif (($rllvrstart2 eq 'l7') or ($rllvrstart2 eq 'L7')) {
			$rllvrstart2 = 'L7';
			$rllvrb19p = 1;	
			$rllvrb20p = 1;
			$rllvrb21p = 1;
		} elsif (($rllvrstart2 eq 'l8') or ($rllvrstart2 eq 'L8')) {
			$rllvrstart2 = 'L8';
			$rllvrb22p = 1;	
			$rllvrb23p = 1;
			$rllvrb24p = 1;
		} elsif (($rllvrstart2 eq 'l9') or ($rllvrstart2 eq 'L9')) {
			$rllvrstart2 = 'L9';
			$rllvrb25p = 1;	
			$rllvrb26p = 1;
			$rllvrb27p = 1;
		} elsif (($rllvrstart2 eq 'l10') or ($rllvrstart2 eq 'L10')) {
			$rllvrstart2 = 'L10';
			$rllvrb28p = 1;	
			$rllvrb29p = 1;
			$rllvrb30p = 1;
		} elsif (($rllvrstart2 eq 'l11') or ($rllvrstart2 eq 'L11')) {
			$rllvrstart2 = 'L11';
			$rllvrb31p = 1;	
			$rllvrb32p = 1;
			$rllvrb33p = 1;
		} elsif (($rllvrstart2 eq 'l12') or ($rllvrstart2 eq 'L12')) {
			$rllvrstart2 = 'L12';
			$rllvrb34p = 1;	
			$rllvrb35p = 1;
			$rllvrb36p = 1;
		} elsif (($rllvrstart2 eq 'z') or ($rllvrstart2 eq 'Z')) {
			$rllvrstart2 = 'Z';
			$rllvrb00p = 1;
			$rllvrb0p = 1;
		} elsif (($rllvrstart2 eq 'f1') or ($rllvrstart2 eq 'F1')) {
			$rllvrstart2 = 'F1';
			$rllvrb1p = 1;	
			$rllvrb2p = 1;
			$rllvrb3p = 1;
			$rllvrb4p = 1;	
			$rllvrb5p = 1;
			$rllvrb6p = 1;	
			$rllvrb7p = 1;
			$rllvrb8p = 1;
			$rllvrb9p = 1;	
			$rllvrb10p = 1;	
			$rllvrb11p = 1;	
			$rllvrb12p = 1;
			$rllvrb13p = 1;
			$rllvrb14p = 1;	
			$rllvrb15p = 1;
			$rllvrb16p = 1;	
			$rllvrb17p = 1;
			$rllvrb18p = 1;
			$rllvrb19p = 1;
			$rllvrb20p = 1;
			$rllvrb21p = 1;
			$rllvrb22p = 1;
			$rllvrb23p = 1;
			$rllvrb24p = 1;
			$rllvrb25p = 1;
			$rllvrb26p = 1;
			$rllvrb27p = 1;
		} elsif (($rllvrstart2 eq 'f2') or ($rllvrstart2 eq 'F2')) {
			$rllvrstart2 = 'F2';
			$rllvrb10p = 1;	
			$rllvrb11p = 1;	
			$rllvrb12p = 1;
			$rllvrb13p = 1;
			$rllvrb14p = 1;	
			$rllvrb15p = 1;
			$rllvrb16p = 1;	
			$rllvrb17p = 1;
			$rllvrb18p = 1;
			$rllvrb19p = 1;
			$rllvrb20p = 1;
			$rllvrb21p = 1;
			$rllvrb22p = 1;
			$rllvrb23p = 1;
			$rllvrb24p = 1;
			$rllvrb25p = 1;
			$rllvrb26p = 1;
			$rllvrb27p = 1;
			$rllvrb28p = 1;
			$rllvrb29p = 1;
			$rllvrb30p = 1;
			$rllvrb31p = 1;
			$rllvrb32p = 1;
			$rllvrb33p = 1;
			$rllvrb34p = 1;
			$rllvrb35p = 1;
			$rllvrb36p = 1;
		} elsif (($rllvrstart2 eq 'f3') or ($rllvrstart2 eq 'F3')) {
			$rllvrstart2 = 'F3';
			$rllvrb1p = 1;	
			$rllvrb2p = 1;	
			$rllvrb3p = 1;
			$rllvrb4p = 1;
			$rllvrb5p = 1;	
			$rllvrb6p = 1;
			$rllvrb7p = 1;	
			$rllvrb8p = 1;
			$rllvrb9p = 1;
			
			$rllvrb19p = 1;
			$rllvrb20p = 1;
			$rllvrb21p = 1;
			$rllvrb22p = 1;
			$rllvrb23p = 1;
			$rllvrb24p = 1;
			$rllvrb25p = 1;
			$rllvrb26p = 1;
			$rllvrb27p = 1;
			$rllvrb28p = 1;
			$rllvrb29p = 1;
			$rllvrb30p = 1;
			$rllvrb31p = 1;
			$rllvrb32p = 1;
			$rllvrb33p = 1;
			$rllvrb34p = 1;
			$rllvrb35p = 1;
			$rllvrb36p = 1;
		} elsif (($rllvrstart2 eq 'f4') or ($rllvrstart2 eq 'F4')) {
			$rllvrstart2 = 'F4';
			$rllvrb1p = 1;	
			$rllvrb2p = 1;	
			$rllvrb3p = 1;
			$rllvrb4p = 1;
			$rllvrb5p = 1;	
			$rllvrb6p = 1;
			$rllvrb7p = 1;	
			$rllvrb8p = 1;
			$rllvrb9p = 1;
			$rllvrb10p = 1;	
			$rllvrb11p = 1;	
			$rllvrb12p = 1;
			$rllvrb13p = 1;
			$rllvrb14p = 1;	
			$rllvrb15p = 1;
			$rllvrb16p = 1;	
			$rllvrb17p = 1;
			$rllvrb18p = 1;
			
			$rllvrb28p = 1;
			$rllvrb29p = 1;
			$rllvrb30p = 1;
			$rllvrb31p = 1;
			$rllvrb32p = 1;
			$rllvrb33p = 1;
			$rllvrb34p = 1;
			$rllvrb35p = 1;
			$rllvrb36p = 1;
		} elsif (($rllvrstart2 eq 't1') or ($rllvrstart2 eq 'T1')) {
			$rllvrstart2 = 'T1';
			$rllvrb1p = 1;	
			$rllvrb2p = 1;
			$rllvrb3p = 1;
			$rllvrb4p = 1;	
			$rllvrb5p = 1;
			$rllvrb6p = 1;	
			$rllvrb7p = 1;
			$rllvrb8p = 1;
			$rllvrb9p = 1;	
			$rllvrb10p = 1;	
			$rllvrb11p = 1;	
			$rllvrb12p = 1;
			$rllvrb13p = 1;
			$rllvrb14p = 1;	
			$rllvrb15p = 1;
			$rllvrb16p = 1;	
			$rllvrb17p = 1;
			$rllvrb18p = 1;
			$rllvrb19p = 1;
			$rllvrb20p = 1;
			$rllvrb21p = 1;
			$rllvrb22p = 1;
			$rllvrb23p = 1;
			$rllvrb24p = 1;
		} elsif (($rllvrstart2 eq 't2') or ($rllvrstart2 eq 'T2')) {
			$rllvrstart2 = 'T2';	
			$rllvrb7p = 1;
			$rllvrb8p = 1;
			$rllvrb9p = 1;	
			$rllvrb10p = 1;	
			$rllvrb11p = 1;	
			$rllvrb12p = 1;
			$rllvrb13p = 1;
			$rllvrb14p = 1;	
			$rllvrb15p = 1;
			$rllvrb16p = 1;	
			$rllvrb17p = 1;
			$rllvrb18p = 1;
			$rllvrb19p = 1;
			$rllvrb20p = 1;
			$rllvrb21p = 1;
			$rllvrb22p = 1;
			$rllvrb23p = 1;
			$rllvrb24p = 1;
			$rllvrb25p = 1;
			$rllvrb26p = 1;
			$rllvrb27p = 1;
			$rllvrb28p = 1;
			$rllvrb29p = 1;
			$rllvrb30p = 1;
		} elsif (($rllvrstart2 eq 't3') or ($rllvrstart2 eq 'T3')) {
			$rllvrstart2 = 'T3';
			$rllvrb13p = 1;
			$rllvrb14p = 1;	
			$rllvrb15p = 1;	
			$rllvrb16p = 1;	
			$rllvrb17p = 1;
			$rllvrb18p = 1;
			$rllvrb19p = 1;	
			$rllvrb20p = 1;
			$rllvrb21p = 1;	
			$rllvrb22p = 1;
			$rllvrb23p = 1;
			$rllvrb24p = 1;
			$rllvrb25p = 1;
			$rllvrb26p = 1;
			$rllvrb27p = 1;
			$rllvrb28p = 1;
			$rllvrb29p = 1;
			$rllvrb30p = 1;
			$rllvrb31p = 1;
			$rllvrb32p = 1;
			$rllvrb33p = 1;
			$rllvrb34p = 1;
			$rllvrb35p = 1;
			$rllvrb36p = 1;
		} elsif (($rllvrsetup == 0) and (($rllvrstart2 eq 'p2') or ($rllvrstart2 eq 'P2'))) {
			$rllvrstart2 = 'P2';
			$rllvrb2p = 1;	
			$rllvrb4p = 1;
			$rllvrb8p = 1;
			$rllvrb16p = 1;
			$rllvrb32p = 1;																																									
		} elsif ((($rllvrstart2 eq 'red') and ($rllvrsetup == 0) and ($rllvrfuturecarlo != 1)) or (($rllvrstart2 eq 'RED') and ($rllvrsetup == 0) and ($rllvrfuturecarlo != 1))) {
			$rllvrstart2 = 'RED';
			$rllvrbRp = 1;
		} elsif ((($rllvrstart2 eq 'magenta') and ($rllvrsetup == 0) and ($rllvrfuturecarlo == 1)) or (($rllvrstart2 eq 'MAGENTA') and ($rllvrsetup == 0) and ($rllvrfuturecarlo == 1))) {
			$rllvrstart2 = 'RED';
			$rllvrbRp = 1;	
		} elsif ((($rllvrstart2 eq 'blue') and ($rllvrsetup == 1)) or (($rllvrstart2 eq 'BLUE') and ($rllvrsetup == 1))) {
			$rllvrstart2 = 'RED';
			$rllvrbRp = 1;
		} elsif ((($rllvrstart2 eq 'blue') and ($rllvrsetup == 0) and ($rllvrfuturecarlo == 1)) or (($rllvrstart2 eq 'BLUE') and ($rllvrsetup == 0) and ($rllvrfuturecarlo == 1))) {
			$rllvrstart2 = 'BLACK';
			$rllvrbBp = 1;		
		} elsif (($rllvrstart2 eq 'black') or ($rllvrstart2 eq 'BLACK')) {
			if (($rllvrsetup == 0) and ($rllvrfuturecarlo != 1)) {
				$rllvrstart2 = 'BLACK';
				$rllvrbBp = 1;
			} elsif ($rllvrsetup == 1) {
				$rllvrstart2 = 'BLACK';
				$rllvrbBp = 1;
			} else {
				$rllvrstart2 = ' ';
			}															
		} else {
			$rllvrstart2 = ' ';
		}
	newlines();	
	rllvrmainspin2();
}

sub rllvrreset {
	$rllvraddmoney = 0;
	$rllvrmoney = 0;
	$rllvrreelspin = 0;
	if (($rllvrsetup != 0) and ($rllvrstart2 eq 'P2')) {
		$rllvrb2p = 0;	
		$rllvrb4p = 0;
		$rllvrb8p = 0;
		$rllvrb16p = 0;
		$rllvrb32p = 0;
		$rllvrstart2 = ' ';
	}
}

sub rllvraddmoney {
	if (($rllvrwinnbr eq '37') and ($rllvrstart2 eq '00')) {
		$rllvraddmoney = $rllvrbet * 36;
		$rllvrstwin = $rllvrstwin + 1;
	} elsif (($rllvrwinnbr eq '38') and ($rllvrstart2 eq '0')) {
		$rllvraddmoney = $rllvrbet * 36;
		$rllvrstwin = $rllvrstwin + 1;	
	} elsif ($rllvrstart2 eq 'EVEN') {
		if (($rllvrwinnbr eq '2') 
		or ($rllvrwinnbr eq '4')
		or ($rllvrwinnbr eq '6')
		or ($rllvrwinnbr eq '8')
		or ($rllvrwinnbr eq '10')
		or ($rllvrwinnbr eq '12')
		or ($rllvrwinnbr eq '14')
		or ($rllvrwinnbr eq '16')
		or ($rllvrwinnbr eq '18')
		or ($rllvrwinnbr eq '20')
		or ($rllvrwinnbr eq '22')
		or ($rllvrwinnbr eq '24')
		or ($rllvrwinnbr eq '26')
		or ($rllvrwinnbr eq '28')
		or ($rllvrwinnbr eq '30')
		or ($rllvrwinnbr eq '32')
		or ($rllvrwinnbr eq '34')
		or ($rllvrwinnbr eq '36')) {
			$rllvraddmoney = $rllvrbet * 2;
			$rllvrstwin = $rllvrstwin + 1;
		} else {
			$rllvraddmoney = 0;
			$rllvrstlose = $rllvrstlose + 1;
		}
	} elsif ($rllvrstart2 eq 'ODD') {
		if (($rllvrwinnbr eq '1') 
		or ($rllvrwinnbr eq '3')
		or ($rllvrwinnbr eq '5')
		or ($rllvrwinnbr eq '7')
		or ($rllvrwinnbr eq '9')
		or ($rllvrwinnbr eq '11')
		or ($rllvrwinnbr eq '13')
		or ($rllvrwinnbr eq '15')
		or ($rllvrwinnbr eq '17')
		or ($rllvrwinnbr eq '19')
		or ($rllvrwinnbr eq '21')
		or ($rllvrwinnbr eq '23')
		or ($rllvrwinnbr eq '25')
		or ($rllvrwinnbr eq '27')
		or ($rllvrwinnbr eq '29')
		or ($rllvrwinnbr eq '31')
		or ($rllvrwinnbr eq '33')
		or ($rllvrwinnbr eq '35')) {
			$rllvraddmoney = $rllvrbet * 2;
			$rllvrstwin = $rllvrstwin + 1;
		} else {
			$rllvraddmoney = 0;
			$rllvrstlose = $rllvrstlose + 1;
		}
	} elsif ($rllvrstart2 eq 'LOWER18') {
		if (($rllvrwinnbr eq '1') 
		or ($rllvrwinnbr eq '2')
		or ($rllvrwinnbr eq '3')
		or ($rllvrwinnbr eq '4')
		or ($rllvrwinnbr eq '5')
		or ($rllvrwinnbr eq '6')
		or ($rllvrwinnbr eq '7')
		or ($rllvrwinnbr eq '8')
		or ($rllvrwinnbr eq '9')
		or ($rllvrwinnbr eq '10')
		or ($rllvrwinnbr eq '11')
		or ($rllvrwinnbr eq '12')
		or ($rllvrwinnbr eq '13')
		or ($rllvrwinnbr eq '14')
		or ($rllvrwinnbr eq '15')
		or ($rllvrwinnbr eq '16')
		or ($rllvrwinnbr eq '17')
		or ($rllvrwinnbr eq '18')) {
			$rllvraddmoney = $rllvrbet * 2;
			$rllvrstwin = $rllvrstwin + 1;
		} else {
			$rllvraddmoney = 0;
			$rllvrstlose = $rllvrstlose + 1;
		}
	} elsif ($rllvrstart2 eq 'UPPER18') {
		if (($rllvrwinnbr eq '19') 
		or ($rllvrwinnbr eq '20')
		or ($rllvrwinnbr eq '21')
		or ($rllvrwinnbr eq '22')
		or ($rllvrwinnbr eq '23')
		or ($rllvrwinnbr eq '24')
		or ($rllvrwinnbr eq '25')
		or ($rllvrwinnbr eq '26')
		or ($rllvrwinnbr eq '27')
		or ($rllvrwinnbr eq '28')
		or ($rllvrwinnbr eq '29')
		or ($rllvrwinnbr eq '30')
		or ($rllvrwinnbr eq '31')
		or ($rllvrwinnbr eq '32')
		or ($rllvrwinnbr eq '33')
		or ($rllvrwinnbr eq '34')
		or ($rllvrwinnbr eq '35')
		or ($rllvrwinnbr eq '36')) {
			$rllvraddmoney = $rllvrbet * 2;
			$rllvrstwin = $rllvrstwin + 1;
		} else {
			$rllvraddmoney = 0;
			$rllvrstlose = $rllvrstlose + 1;
		}
	} elsif ($rllvrstart2 eq 'BLACK') {
		if (($rllvrwinnbr eq '28') 
		or ($rllvrwinnbr eq '26')
		or ($rllvrwinnbr eq '11')
		or ($rllvrwinnbr eq '20')
		or ($rllvrwinnbr eq '17')
		or ($rllvrwinnbr eq '22')
		or ($rllvrwinnbr eq '15')
		or ($rllvrwinnbr eq '24')
		or ($rllvrwinnbr eq '13')
		or ($rllvrwinnbr eq '10')
		or ($rllvrwinnbr eq '29')
		or ($rllvrwinnbr eq '8')
		or ($rllvrwinnbr eq '31')
		or ($rllvrwinnbr eq '6')
		or ($rllvrwinnbr eq '33')
		or ($rllvrwinnbr eq '4')
		or ($rllvrwinnbr eq '35')
		or ($rllvrwinnbr eq '2')) {
			$rllvraddmoney = $rllvrbet * 2;
			$rllvrstwin = $rllvrstwin + 1;
		} else {
			$rllvraddmoney = 0;
			$rllvrstlose = $rllvrstlose + 1;
		}
	} elsif ($rllvrstart2 eq 'RED') {
		if (($rllvrwinnbr eq '9') 
		or ($rllvrwinnbr eq '30')
		or ($rllvrwinnbr eq '7')
		or ($rllvrwinnbr eq '32')
		or ($rllvrwinnbr eq '5')
		or ($rllvrwinnbr eq '34')
		or ($rllvrwinnbr eq '3')
		or ($rllvrwinnbr eq '36')
		or ($rllvrwinnbr eq '1')
		or ($rllvrwinnbr eq '27')
		or ($rllvrwinnbr eq '25')
		or ($rllvrwinnbr eq '12')
		or ($rllvrwinnbr eq '19')
		or ($rllvrwinnbr eq '18')
		or ($rllvrwinnbr eq '21')
		or ($rllvrwinnbr eq '16')
		or ($rllvrwinnbr eq '23')
		or ($rllvrwinnbr eq '14')) {
			$rllvraddmoney = $rllvrbet * 2;
			$rllvrstwin = $rllvrstwin + 1;
		} else {
			$rllvraddmoney = 0;
			$rllvrstlose = $rllvrstlose + 1;
		}				
	} elsif ($rllvrstart2 eq 'C1') {
		if (($rllvrwinnbr eq '1') 
		or ($rllvrwinnbr eq '4')
		or ($rllvrwinnbr eq '7')
		or ($rllvrwinnbr eq '10')
		or ($rllvrwinnbr eq '13')
		or ($rllvrwinnbr eq '16')
		or ($rllvrwinnbr eq '19')
		or ($rllvrwinnbr eq '22')
		or ($rllvrwinnbr eq '25')
		or ($rllvrwinnbr eq '28')
		or ($rllvrwinnbr eq '31')
		or ($rllvrwinnbr eq '34')) {
			$rllvraddmoney = $rllvrbet * 3;
			$rllvrstwin = $rllvrstwin + 1;
		} else {
			$rllvraddmoney = 0;
			$rllvrstlose = $rllvrstlose + 1;
		}
	} elsif ($rllvrstart2 eq 'C2') {
		if (($rllvrwinnbr eq '2') 
		or ($rllvrwinnbr eq '5')
		or ($rllvrwinnbr eq '8')
		or ($rllvrwinnbr eq '11')
		or ($rllvrwinnbr eq '14')
		or ($rllvrwinnbr eq '17')
		or ($rllvrwinnbr eq '20')
		or ($rllvrwinnbr eq '23')
		or ($rllvrwinnbr eq '26')
		or ($rllvrwinnbr eq '29')
		or ($rllvrwinnbr eq '32')
		or ($rllvrwinnbr eq '35')) {
			$rllvraddmoney = $rllvrbet * 3;
			$rllvrstwin = $rllvrstwin + 1;
		} else {
			$rllvraddmoney = 0;
			$rllvrstlose = $rllvrstlose + 1;
		}
	} elsif ($rllvrstart2 eq 'C3') {
		if (($rllvrwinnbr eq '3') 
		or ($rllvrwinnbr eq '6')
		or ($rllvrwinnbr eq '9')
		or ($rllvrwinnbr eq '12')
		or ($rllvrwinnbr eq '15')
		or ($rllvrwinnbr eq '18')
		or ($rllvrwinnbr eq '21')
		or ($rllvrwinnbr eq '24')
		or ($rllvrwinnbr eq '27')
		or ($rllvrwinnbr eq '30')
		or ($rllvrwinnbr eq '33')
		or ($rllvrwinnbr eq '36')) {
			$rllvraddmoney = $rllvrbet * 3;
			$rllvrstwin = $rllvrstwin + 1;
		} else {
			$rllvraddmoney = 0;
			$rllvrstlose = $rllvrstlose + 1;
		}
	} elsif ($rllvrstart2 eq 'G1') {
		if (($rllvrwinnbr eq '1') 
		or ($rllvrwinnbr eq '2')
		or ($rllvrwinnbr eq '3')
		or ($rllvrwinnbr eq '4')
		or ($rllvrwinnbr eq '5')
		or ($rllvrwinnbr eq '6')
		or ($rllvrwinnbr eq '7')
		or ($rllvrwinnbr eq '8')
		or ($rllvrwinnbr eq '9')) {
			$rllvraddmoney = $rllvrbet * 4;
			$rllvrstwin = $rllvrstwin + 1;
		} else {
			$rllvraddmoney = 0;
			$rllvrstlose = $rllvrstlose + 1;
		}
	} elsif ($rllvrstart2 eq 'G2') {
		if (($rllvrwinnbr eq '10') 
		or ($rllvrwinnbr eq '11')
		or ($rllvrwinnbr eq '12')
		or ($rllvrwinnbr eq '13')
		or ($rllvrwinnbr eq '14')
		or ($rllvrwinnbr eq '15')
		or ($rllvrwinnbr eq '16')
		or ($rllvrwinnbr eq '17')
		or ($rllvrwinnbr eq '18')) {
			$rllvraddmoney = $rllvrbet * 4;
			$rllvrstwin = $rllvrstwin + 1;
		} else {
			$rllvraddmoney = 0;
			$rllvrstlose = $rllvrstlose + 1;
		}
	} elsif ($rllvrstart2 eq 'G3') {
		if (($rllvrwinnbr eq '19') 
		or ($rllvrwinnbr eq '20')
		or ($rllvrwinnbr eq '21')
		or ($rllvrwinnbr eq '22')
		or ($rllvrwinnbr eq '23')
		or ($rllvrwinnbr eq '24')
		or ($rllvrwinnbr eq '25')
		or ($rllvrwinnbr eq '26')
		or ($rllvrwinnbr eq '27')) {
			$rllvraddmoney = $rllvrbet * 4;
			$rllvrstwin = $rllvrstwin + 1;
		} else {
			$rllvraddmoney = 0;
			$rllvrstlose = $rllvrstlose + 1;
		}	
	} elsif ($rllvrstart2 eq 'G4') {
		if (($rllvrwinnbr eq '28') 
		or ($rllvrwinnbr eq '29')
		or ($rllvrwinnbr eq '30')
		or ($rllvrwinnbr eq '31')
		or ($rllvrwinnbr eq '32')
		or ($rllvrwinnbr eq '33')
		or ($rllvrwinnbr eq '34')
		or ($rllvrwinnbr eq '35')
		or ($rllvrwinnbr eq '36')) {
			$rllvraddmoney = $rllvrbet * 4;
			$rllvrstwin = $rllvrstwin + 1;
		} else {
			$rllvraddmoney = 0;
			$rllvrstlose = $rllvrstlose + 1;
		}
	} elsif ($rllvrstart2 eq 'L1') {
		if (($rllvrwinnbr eq '1') 
		or ($rllvrwinnbr eq '2')
		or ($rllvrwinnbr eq '3')) {
			$rllvraddmoney = $rllvrbet * 12;
			$rllvrstwin = $rllvrstwin + 1;
		} else {
			$rllvraddmoney = 0;
			$rllvrstlose = $rllvrstlose + 1;
		}
	} elsif ($rllvrstart2 eq 'L2') {
		if (($rllvrwinnbr eq '4') 
		or ($rllvrwinnbr eq '5')
		or ($rllvrwinnbr eq '6')) {
			$rllvraddmoney = $rllvrbet * 12;
			$rllvrstwin = $rllvrstwin + 1;
		} else {
			$rllvraddmoney = 0;
			$rllvrstlose = $rllvrstlose + 1;
		}
	} elsif ($rllvrstart2 eq 'L3') {
		if (($rllvrwinnbr eq '7') 
		or ($rllvrwinnbr eq '8')
		or ($rllvrwinnbr eq '9')) {
			$rllvraddmoney = $rllvrbet * 12;
			$rllvrstwin = $rllvrstwin + 1;
		} else {
			$rllvraddmoney = 0;
			$rllvrstlose = $rllvrstlose + 1;
		}
	} elsif ($rllvrstart2 eq 'L4') {
		if (($rllvrwinnbr eq '10') 
		or ($rllvrwinnbr eq '11')
		or ($rllvrwinnbr eq '12')) {
			$rllvraddmoney = $rllvrbet * 12;
			$rllvrstwin = $rllvrstwin + 1;
		} else {
			$rllvraddmoney = 0;
			$rllvrstlose = $rllvrstlose + 1;
		}
	} elsif ($rllvrstart2 eq 'L5') {
		if (($rllvrwinnbr eq '13') 
		or ($rllvrwinnbr eq '14')
		or ($rllvrwinnbr eq '15')) {
			$rllvraddmoney = $rllvrbet * 12;
			$rllvrstwin = $rllvrstwin + 1;
		} else {
			$rllvraddmoney = 0;
			$rllvrstlose = $rllvrstlose + 1;
		}
	} elsif ($rllvrstart2 eq 'L6') {
		if (($rllvrwinnbr eq '16') 
		or ($rllvrwinnbr eq '17')
		or ($rllvrwinnbr eq '18')) {
			$rllvraddmoney = $rllvrbet * 12;
			$rllvrstwin = $rllvrstwin + 1;
		} else {
			$rllvraddmoney = 0;
			$rllvrstlose = $rllvrstlose + 1;
		}
	} elsif ($rllvrstart2 eq 'L7') {
		if (($rllvrwinnbr eq '19') 
		or ($rllvrwinnbr eq '20')
		or ($rllvrwinnbr eq '21')) {
			$rllvraddmoney = $rllvrbet * 12;
			$rllvrstwin = $rllvrstwin + 1;
		} else {
			$rllvraddmoney = 0;
			$rllvrstlose = $rllvrstlose + 1;
		}
	} elsif ($rllvrstart2 eq 'L8') {
		if (($rllvrwinnbr eq '22') 
		or ($rllvrwinnbr eq '23')
		or ($rllvrwinnbr eq '24')) {
			$rllvraddmoney = $rllvrbet * 12;
			$rllvrstwin = $rllvrstwin + 1;
		} else {
			$rllvraddmoney = 0;
			$rllvrstlose = $rllvrstlose + 1;
		}
	} elsif ($rllvrstart2 eq 'L9') {
		if (($rllvrwinnbr eq '25') 
		or ($rllvrwinnbr eq '26')
		or ($rllvrwinnbr eq '27')) {
			$rllvraddmoney = $rllvrbet * 12;
			$rllvrstwin = $rllvrstwin + 1;
		} else {
			$rllvraddmoney = 0;
			$rllvrstlose = $rllvrstlose + 1;
		}
	} elsif ($rllvrstart2 eq 'L10') {
		if (($rllvrwinnbr eq '28') 
		or ($rllvrwinnbr eq '29')
		or ($rllvrwinnbr eq '30')) {
			$rllvraddmoney = $rllvrbet * 12;
			$rllvrstwin = $rllvrstwin + 1;
		} else {
			$rllvraddmoney = 0;
			$rllvrstlose = $rllvrstlose + 1;
		}
	} elsif ($rllvrstart2 eq 'L11') {
		if (($rllvrwinnbr eq '31') 
		or ($rllvrwinnbr eq '32')
		or ($rllvrwinnbr eq '33')) {
			$rllvraddmoney = $rllvrbet * 12;
			$rllvrstwin = $rllvrstwin + 1;
		} else {
			$rllvraddmoney = 0;
			$rllvrstlose = $rllvrstlose + 1;
		}
	} elsif ($rllvrstart2 eq 'L12') {
		if (($rllvrwinnbr eq '34') 
		or ($rllvrwinnbr eq '35')
		or ($rllvrwinnbr eq '36')) {
			$rllvraddmoney = $rllvrbet * 12;
			$rllvrstwin = $rllvrstwin + 1;
		} else {
			$rllvraddmoney = 0;
			$rllvrstlose = $rllvrstlose + 1;
		}
	} elsif ($rllvrstart2 eq 'Z') {
		#37 = 0, 38 = 00
		if (($rllvrwinnbr eq '37') 
		or ($rllvrwinnbr eq '38')) {
			$rllvraddmoney = $rllvrbet * 18;
			$rllvrstwin = $rllvrstwin + 1;
		} else {
			$rllvraddmoney = 0;
			$rllvrstlose = $rllvrstlose + 1;
		}
	} elsif ($rllvrstart2 eq 'F1') {
		if (($rllvrwinnbr eq '1') 
		or ($rllvrwinnbr eq '2')
		or ($rllvrwinnbr eq '4')
		or ($rllvrwinnbr eq '5')
		or ($rllvrwinnbr eq '6')
		or ($rllvrwinnbr eq '7')
		or ($rllvrwinnbr eq '8')
		or ($rllvrwinnbr eq '9')
		or ($rllvrwinnbr eq '10')
		or ($rllvrwinnbr eq '11')
		or ($rllvrwinnbr eq '12')
		or ($rllvrwinnbr eq '13')
		or ($rllvrwinnbr eq '14')
		or ($rllvrwinnbr eq '15')
		or ($rllvrwinnbr eq '16')
		or ($rllvrwinnbr eq '17')
		or ($rllvrwinnbr eq '18')
		or ($rllvrwinnbr eq '19')
		or ($rllvrwinnbr eq '20')
		or ($rllvrwinnbr eq '21')
		or ($rllvrwinnbr eq '22')
		or ($rllvrwinnbr eq '23')
		or ($rllvrwinnbr eq '24')
		or ($rllvrwinnbr eq '25')
		or ($rllvrwinnbr eq '26')
		or ($rllvrwinnbr eq '27')) {
			$rllvraddmoney = ($rllvrbet + ($rllvrbet/3));
			$rllvraddmoney = int($rllvraddmoney);
			$rllvrstwin = $rllvrstwin + 1;
		} else {
			$rllvraddmoney = 0;
			$rllvrstlose = $rllvrstlose + 1;
		}
	} elsif ($rllvrstart2 eq 'F2') {
		if (($rllvrwinnbr eq '10') 
		or ($rllvrwinnbr eq '11')
		or ($rllvrwinnbr eq '12')
		or ($rllvrwinnbr eq '13')
		or ($rllvrwinnbr eq '14')
		or ($rllvrwinnbr eq '15')
		or ($rllvrwinnbr eq '16')
		or ($rllvrwinnbr eq '17')
		or ($rllvrwinnbr eq '18')
		or ($rllvrwinnbr eq '19')
		or ($rllvrwinnbr eq '20')
		or ($rllvrwinnbr eq '21')
		or ($rllvrwinnbr eq '22')
		or ($rllvrwinnbr eq '23')
		or ($rllvrwinnbr eq '24')
		or ($rllvrwinnbr eq '25')
		or ($rllvrwinnbr eq '26')
		or ($rllvrwinnbr eq '27')
		or ($rllvrwinnbr eq '28')
		or ($rllvrwinnbr eq '29')
		or ($rllvrwinnbr eq '30')
		or ($rllvrwinnbr eq '31')
		or ($rllvrwinnbr eq '32')
		or ($rllvrwinnbr eq '33')
		or ($rllvrwinnbr eq '34')
		or ($rllvrwinnbr eq '35')
		or ($rllvrwinnbr eq '36')) {
			$rllvraddmoney = ($rllvrbet + ($rllvrbet/3));
			$rllvraddmoney = int($rllvraddmoney);
			$rllvrstwin = $rllvrstwin + 1;
		} else {
			$rllvraddmoney = 0;
			$rllvrstlose = $rllvrstlose + 1;
		}
	} elsif ($rllvrstart2 eq 'F3') {
		if (($rllvrwinnbr eq '1') 
		or ($rllvrwinnbr eq '2')
		or ($rllvrwinnbr eq '4')
		or ($rllvrwinnbr eq '5')
		or ($rllvrwinnbr eq '6')
		or ($rllvrwinnbr eq '7')
		or ($rllvrwinnbr eq '8')
		or ($rllvrwinnbr eq '9')
		
		or ($rllvrwinnbr eq '19')
		or ($rllvrwinnbr eq '20')
		or ($rllvrwinnbr eq '21')
		or ($rllvrwinnbr eq '22')
		or ($rllvrwinnbr eq '23')
		or ($rllvrwinnbr eq '24')
		or ($rllvrwinnbr eq '25')
		or ($rllvrwinnbr eq '26')
		or ($rllvrwinnbr eq '27')
		or ($rllvrwinnbr eq '28')
		or ($rllvrwinnbr eq '29')
		or ($rllvrwinnbr eq '30')
		or ($rllvrwinnbr eq '31')
		or ($rllvrwinnbr eq '32')
		or ($rllvrwinnbr eq '33')
		or ($rllvrwinnbr eq '34')
		or ($rllvrwinnbr eq '35')
		or ($rllvrwinnbr eq '36')) {
			$rllvraddmoney = ($rllvrbet + ($rllvrbet/3));
			$rllvraddmoney = int($rllvraddmoney);
			$rllvrstwin = $rllvrstwin + 1;
		} else {
			$rllvraddmoney = 0;
			$rllvrstlose = $rllvrstlose + 1;
		}
	} elsif ($rllvrstart2 eq 'F4') {
		if (($rllvrwinnbr eq '1') 
		or ($rllvrwinnbr eq '2')
		or ($rllvrwinnbr eq '4')
		or ($rllvrwinnbr eq '5')
		or ($rllvrwinnbr eq '6')
		or ($rllvrwinnbr eq '7')
		or ($rllvrwinnbr eq '8')
		or ($rllvrwinnbr eq '9')
		or ($rllvrwinnbr eq '10') 
		or ($rllvrwinnbr eq '11')
		or ($rllvrwinnbr eq '12')
		or ($rllvrwinnbr eq '13')
		or ($rllvrwinnbr eq '14')
		or ($rllvrwinnbr eq '15')
		or ($rllvrwinnbr eq '16')
		or ($rllvrwinnbr eq '17')
		or ($rllvrwinnbr eq '18')
		or ($rllvrwinnbr eq '28')
		
		or ($rllvrwinnbr eq '29')
		or ($rllvrwinnbr eq '30')
		or ($rllvrwinnbr eq '31')
		or ($rllvrwinnbr eq '32')
		or ($rllvrwinnbr eq '33')
		or ($rllvrwinnbr eq '34')
		or ($rllvrwinnbr eq '35')
		or ($rllvrwinnbr eq '36')) {
			$rllvraddmoney = ($rllvrbet + ($rllvrbet/3));
			$rllvraddmoney = int($rllvraddmoney);
			$rllvrstwin = $rllvrstwin + 1;
		} else {
			$rllvraddmoney = 0;
			$rllvrstlose = $rllvrstlose + 1;
		}
	} elsif ($rllvrstart2 eq 'T1') {
		if (($rllvrwinnbr eq '1') 
		or ($rllvrwinnbr eq '2')
		or ($rllvrwinnbr eq '3')
		or ($rllvrwinnbr eq '4')
		or ($rllvrwinnbr eq '5')
		or ($rllvrwinnbr eq '6')
		or ($rllvrwinnbr eq '7')
		or ($rllvrwinnbr eq '8')
		or ($rllvrwinnbr eq '9')
		or ($rllvrwinnbr eq '10')
		or ($rllvrwinnbr eq '11')
		or ($rllvrwinnbr eq '12')
		or ($rllvrwinnbr eq '13')
		or ($rllvrwinnbr eq '14')
		or ($rllvrwinnbr eq '15')
		or ($rllvrwinnbr eq '16')
		or ($rllvrwinnbr eq '17')
		or ($rllvrwinnbr eq '18')
		or ($rllvrwinnbr eq '19')
		or ($rllvrwinnbr eq '20')
		or ($rllvrwinnbr eq '21')
		or ($rllvrwinnbr eq '22')
		or ($rllvrwinnbr eq '23')
		or ($rllvrwinnbr eq '24')) {
			$rllvraddmoney = $rllvrbet * 1.5;
			$rllvraddmoney = int($rllvraddmoney);
			$rllvrstwin = $rllvrstwin + 1;
		} else {
			$rllvraddmoney = 0;
			$rllvrstlose = $rllvrstlose + 1;
		}
	} elsif ($rllvrstart2 eq 'T2') {
		if (($rllvrwinnbr eq '7') 
		or ($rllvrwinnbr eq '8')
		or ($rllvrwinnbr eq '9')
		or ($rllvrwinnbr eq '10')
		or ($rllvrwinnbr eq '11')
		or ($rllvrwinnbr eq '12')
		or ($rllvrwinnbr eq '13')
		or ($rllvrwinnbr eq '14')
		or ($rllvrwinnbr eq '15')
		or ($rllvrwinnbr eq '16')
		or ($rllvrwinnbr eq '17')
		or ($rllvrwinnbr eq '18')
		or ($rllvrwinnbr eq '19')
		or ($rllvrwinnbr eq '20')
		or ($rllvrwinnbr eq '21')
		or ($rllvrwinnbr eq '22')
		or ($rllvrwinnbr eq '23')
		or ($rllvrwinnbr eq '24')
		or ($rllvrwinnbr eq '25')
		or ($rllvrwinnbr eq '26')
		or ($rllvrwinnbr eq '27')
		or ($rllvrwinnbr eq '28')
		or ($rllvrwinnbr eq '29')
		or ($rllvrwinnbr eq '30')) {
			$rllvraddmoney = $rllvrbet * 1.5;
			$rllvraddmoney = int($rllvraddmoney);
			$rllvrstwin = $rllvrstwin + 1;
		} else {
			$rllvraddmoney = 0;
			$rllvrstlose = $rllvrstlose + 1;
		}
	} elsif ($rllvrstart2 eq 'T3') {
		if (($rllvrwinnbr eq '13') 
		or ($rllvrwinnbr eq '14')
		or ($rllvrwinnbr eq '15')
		or ($rllvrwinnbr eq '16')
		or ($rllvrwinnbr eq '17')
		or ($rllvrwinnbr eq '18')
		or ($rllvrwinnbr eq '19')
		or ($rllvrwinnbr eq '20')
		or ($rllvrwinnbr eq '21')
		or ($rllvrwinnbr eq '22')
		or ($rllvrwinnbr eq '23')
		or ($rllvrwinnbr eq '24')
		or ($rllvrwinnbr eq '25')
		or ($rllvrwinnbr eq '26')
		or ($rllvrwinnbr eq '27')
		or ($rllvrwinnbr eq '28')
		or ($rllvrwinnbr eq '29')
		or ($rllvrwinnbr eq '30')
		or ($rllvrwinnbr eq '31')
		or ($rllvrwinnbr eq '32')
		or ($rllvrwinnbr eq '33')
		or ($rllvrwinnbr eq '34')
		or ($rllvrwinnbr eq '35')
		or ($rllvrwinnbr eq '36')) {
			$rllvraddmoney = $rllvrbet * 1.5;
			$rllvraddmoney = int($rllvraddmoney);
			$rllvrstwin = $rllvrstwin + 1;
		} else {
			$rllvraddmoney = 0;
			$rllvrstlose = $rllvrstlose + 1;
		}
	} elsif (($rllvrsetup == 0) and ($rllvrstart2 eq 'P2')) {
		#Valid for only Monte Carlo Roulette
		if (($rllvrwinnbr eq '2') 
		or ($rllvrwinnbr eq '4')
		or ($rllvrwinnbr eq '8')
		or ($rllvrwinnbr eq '16') 
		or ($rllvrwinnbr eq '32')) {
			$rllvraddmoney = $rllvrbet * 7;
			$rllvrstwin = $rllvrstwin + 1;
		} else {
			$rllvraddmoney = 0;
			$rllvrstlose = $rllvrstlose + 1;
		}																	
	} elsif ($rllvrstart2 eq $rllvrwinnbr) {
		$rllvraddmoney = $rllvrbet * 36;
		$rllvrstwin = $rllvrstwin + 1;		
	} else {
		$rllvraddmoney = 0;
		$rllvrstlose = $rllvrstlose + 1;
	}

	$rllvrstmc = $rllvrstmc + $rllvraddmoney;
	$rllvrmoney = $rllvraddmoney;
	$money = $money + $rllvraddmoney;
}

sub rllvrbetspin4 {
	rllvrreset();	
	rllvrcolorsg();
	rllvrbetcomp();
	rllvrwheel();
	rllvrprintmain();
	$rllvrstart3 = <STDIN>;
	chomp($rllvrstart3);
	
	if ($rllvrstart3 > $money) {
		$rllvrbet = 0;
	} elsif ($rllvrstart3 <= 0) {
		$rllvrbet = 0;	 	
	} else {
		$rllvrbet = sprintf("%.0f", $rllvrstart3 )
	}
	newlines();
	rllvrmainspin2();
}

sub rllvrnbrreset {
	$rllvrbRp = 0;
	$rllvrbBp = 0;
	$rllvrb00p = 0;
	$rllvrb0p = 0;
	$rllvrb1p = 0;
	$rllvrb2p = 0;	
	$rllvrb3p = 0;	
	$rllvrb4p = 0;
	$rllvrb5p = 0;
	$rllvrb6p = 0;
	$rllvrb7p = 0;	
	$rllvrb8p = 0;	
	$rllvrb9p = 0;
	$rllvrb10p = 0;
	$rllvrb11p = 0;
	$rllvrb12p = 0;	
	$rllvrb13p = 0;	
	$rllvrb14p = 0;
	$rllvrb15p = 0;
	$rllvrb16p = 0;
	$rllvrb17p = 0;	
	$rllvrb18p = 0;	
	$rllvrb19p = 0;
	$rllvrb20p = 0;	
	$rllvrb21p = 0;
	$rllvrb22p = 0;	
	$rllvrb23p = 0;	
	$rllvrb24p = 0;
	$rllvrb25p = 0;
	$rllvrb26p = 0;
	$rllvrb27p = 0;	
	$rllvrb28p = 0;	
	$rllvrb29p = 0;
	$rllvrb30p = 0;
	$rllvrb31p = 0;
	$rllvrb32p = 0;	
	$rllvrb33p = 0;	
	$rllvrb34p = 0;
	$rllvrb35p = 0;
	$rllvrb36p = 0;			
}

sub rllvrstdin1 {
	$rllvrstart1 = <STDIN>;
	chomp($rllvrstart1);
	if (($rllvrstart1 eq 'P') or ($rllvrstart1 eq 'p') or ($rllvrstart1 eq 'a') or ($rllvrstart1 eq 'A')) {
		if ($rllvrstart2 eq ' ') {
			newlines();
			rllvrmainspin2();
		} elsif ($rllvrbet == 0) {
			newlines();
			rllvrmainspin2();				
		} elsif ($money >= $rllvrbet) {
			$money = $money - $rllvrbet;
			$moneyexp = $moneyexp + $rllvrbet;
			$rllvrstmc2 = $rllvrstmc2 + $rllvrbet;
			$rllvrstspins = $rllvrstspins + 1;
			newlines();
			rllvrmainspin1();
		} else {
			newlines();
			rllvrmainspin2();
		}
	} elsif (($rllvrstart1 eq 'N') or ($rllvrstart1 eq 'n')) {
		newlines();
		rllvrnbrspin3();
	} elsif (($rllvrstart1 eq 'B') or ($rllvrstart1 eq 'b')) {
		newlines();
		rllvrbetspin4();
	} elsif (($rllvrstart1 eq 'C') or ($rllvrstart1 eq 'c')) {
		print "\n";
		return;
	} elsif (($rllvrstart1 eq 'EXIT') or ($rllvrstart1 eq 'exit') or ($rllvrstart1 eq 'QUIT') or ($rllvrstart1 eq 'quit')) {
		exitgame();					
	} else {
		newlines();
		rllvrmainspin2();
	}
}


sub rllvrcolorsg {
	if ($rllvrsetup == 0) {
		if ($rllvrfuturecarlo == 1) {
			rllvrcolorfuturecarlo();
		} else {
			rllvrcolormontecarlo();
		}
	} else {
		rllvrcoloramerican();
	}
}

sub rllvrcolormontecarlo {
	$rllvrredvar = '  R E D ';
	$rllvrblkvar = ' B L K  ';
	$rllvrcolor1 = "$bgcgreen";   #0 background
	$rllvrcolor2 = "$bgcblack";   #black background 
	$rllvrcolor3 = "$bgcred";     #red background
	$rllvrcolor2b = "$boldblack";   #black foreground  
	$rllvrcolor3b = "$boldred";     #red foreground
	$rllvrcolor4 = "$boldyellow";  #0 forground
	$rllvrcolor5 = "$bgcwhite";   #divider background
	$rllvrcolor6 = "$boldwhite";  #divider forground
	$rllvrcolor7 = "$bgcblack";    #border background
	$rllvrcolor8 = "$boldblack";   #border forground
	$rllvrcolor9 = "$bgcgreen";   #wheel2 background
	$rllvrcolor10 = "$boldgreen"; #wheel2 forground
	$rllvrcolor11 = "$boldwhite"; #wheel2 forground
	$rllvrcolor12 = "$white";     #wheel2 ball forground
	$rllvrcolor13 = "$boldgreen"; #total forground
	$rllvrcolor14 = "$bgcgreen";  #total background
	$rllvrcolor15 = "$boldyellow";      #title forground
	$rllvrcolor16 = "$white"; #total number forground
	$rllvrcolor17 = "$bgcblack";   #title number background
	$rllvrcolor18 = "$boldyellow";#total highlight number forground
	$rllvrcolor19 = "$bgcwhite";   #title highlight number background
	$rllvrcolor20 = "$boldblack"; #computer border forground
	$rllvrcolor21 = "$bgcwhite";  #computer border background
	$rllvrcolor22 = "$black"; #computer forground 1
	$rllvrcolor23 = "$bgcred";   #computer background 1
	$rllvrcolor24 = "$black"; #computer forground 2
	$rllvrcolor25 = "$bgcred";   #computer background 2
	
}

sub rllvrcolorfuturecarlo {
	$rllvrredvar = ' MAGENTA';
	$rllvrblkvar = '  BLUE  ';
	$rllvrcolor1 = "$bgcgreen";    #0 background
	$rllvrcolor2 = "$bgcblue";    #black background   
	$rllvrcolor3 = "$bgcmagenta"; #red background
	$rllvrcolor2b = "$boldyellow";   #black foreground  
	$rllvrcolor3b = "$boldgreen";     #red foreground
	$rllvrcolor4 = "$boldmagenta";  #0 forground
	$rllvrcolor5 = "$bgcwhite";   #divider background
	$rllvrcolor6 = "$boldwhite";  #divider forground
	$rllvrcolor7 = "$bgcmagenta";    #border background
	$rllvrcolor8 = "$boldmagenta";   #border forground
	$rllvrcolor9 = "$bgcblack";   #wheel2 background
	$rllvrcolor10 = "$boldblack"; #wheel2 forground
	$rllvrcolor11 = "$boldwhite"; #wheel2 forground
	$rllvrcolor12 = "$white";     #wheel2 ball forground
	$rllvrcolor13 = "$boldgreen"; #total forground
	$rllvrcolor14 = "$bgcgreen";  #total background
	$rllvrcolor15 = "$boldyellow";      #title forground
	$rllvrcolor16 = "$boldwhite"; #total number forground
	$rllvrcolor17 = "$bgcmagenta";   #title number background
	$rllvrcolor18 = "$boldyellow";#total highlight number forground
	$rllvrcolor19 = "$bgccyan";   #title highlight number background
	$rllvrcolor20 = "$boldblack"; #computer border forground
	$rllvrcolor21 = "$bgcwhite";  #computer border background
	$rllvrcolor22 = "$black"; #computer forground 1
	$rllvrcolor23 = "$bgccyan";   #computer background 1
	$rllvrcolor24 = "$black"; #computer forground 2
	$rllvrcolor25 = "$bgccyan";   #computer background 2
}

sub rllvrcoloramerican {
	$rllvrredvar = '  B L U ';
	$rllvrblkvar = ' B L K  ';
	$rllvrcolor1 = "$bgcred";     #0 background
	$rllvrcolor2 = "$bgcblack";   #black background   
	$rllvrcolor3 = "$bgcblue";    #red background
	$rllvrcolor2b = "$boldblue";   #black foreground  
	$rllvrcolor3b = "$boldblack";     #red foreground
	$rllvrcolor4 = "$boldwhite";  #0 forground
	$rllvrcolor5 = "$bgcwhite";   #divider background
	$rllvrcolor6 = "$boldwhite";  #divider forground
	$rllvrcolor7 = "$bgcwhite";   #border background
	$rllvrcolor8 = "$boldwhite";  #border forground
	$rllvrcolor9 = "$bgcblack";   #wheel2 background
	$rllvrcolor10 = "$boldblack"; #wheel2 forground
	$rllvrcolor11 = "$boldwhite"; #wheel2 forground
	$rllvrcolor12 = "$white";     #wheel2 ball forground
	$rllvrcolor13 = "$boldblue";  #total forground
	$rllvrcolor14 = "$bgcblue";   #total background
	$rllvrcolor15 = "$blue";      #title forground
	$rllvrcolor16 = "$boldblue";  #total number forground
	$rllvrcolor17 = "$bgcwhite";  #title number background
	$rllvrcolor18 = "$boldwhite"; #total highlight number forground
	$rllvrcolor19 = "$bgcblue";   #title highlight number background
	$rllvrcolor20 = "$boldblack"; #computer border forground
	$rllvrcolor21 = "$bgcblack";  #computer border background
	$rllvrcolor22 = "$boldwhite"; #computer forground 1
	$rllvrcolor23 = "$bgcred";    #computer background 1
	$rllvrcolor24 = "$blue";      #computer forground 2
	$rllvrcolor25 = "$bgcwhite";  #computer background 2
}

sub rllvrcolorcA {
	$rllvrnbr = $rllvrslotA; 
	$rllvrC1 = $rllvrcolorAb;
	$rllvrC2 = $rllvrcolorA;
}

sub rllvrcolorcB {
	$rllvrnbr = $rllvrslotB; 
	$rllvrC1 = $rllvrcolorBb;
	$rllvrC2 = $rllvrcolorB;
}

sub rllvrcolorcC {
	$rllvrnbr = $rllvrslotC; 
	$rllvrC1 = $rllvrcolorCb;
	$rllvrC2 = $rllvrcolorC;
}

sub rllvrcolorcD {
	$rllvrnbr = $rllvrslotD; 
	$rllvrC1 = $rllvrcolorDb;
	$rllvrC2 = $rllvrcolorD;
}

sub rllvrcolorcE {
	$rllvrnbr = $rllvrslotE; 
	$rllvrC1 = $rllvrcolorEb;
	$rllvrC2 = $rllvrcolorE;
}

sub rllvrspin {
	$rllvrwinnbr = int(rand(42));
	
	if ($rllvrwinnbr == 0) {
		rllvrspin();
	} elsif ($rllvrwinnbr >= 39) {
		rllvrspin();	
	}
}

sub rllvrslot1 {
	sep; print colored('         ',"$rllvrC1 on_$rllvrC2"); sep; 
}

sub rllvrslot2 {
	sep; print colored("   $rllvrnbr   ","$rllvrC1 on_$rllvrC2"); sep; 
}

sub rllvrslot3 {
	sep; print colored('-----------',"$rllvrcolor6 on_$rllvrcolor5"); sep; 
}

sub rllvrslot4 {
	sep; print colored(' ',"$rllvrcolor6 on_$rllvrcolor5"); sep; 
}

sub rllvrslot5 {
	print colored('|',"$rllvrcolor8 on_$rllvrcolor7");
}

sub rllvrslot6 {
	sep; print colored('-----------',"$rllvrcolor10 on_$rllvrcolor9"); sep; 
}

sub rllvrslot7 {
	sep; print colored('           ',"$rllvrcolor10 on_$rllvrcolor9"); sep; 
}

sub rllvrslot8 {
	sep; 
	if ($rllvrreelspin == 0) {
		print colored('   /\\|/\\   ',"$rllvrcolor11 on_$rllvrcolor9");
	} elsif ($rllvrreelspin == 1) {
		print colored('   /\\|/\\   ',"$rllvrcolor12 on_$rllvrcolor9");
	} else {
		print colored('           ',"$rllvrcolor12 on_$rllvrcolor9");
	}
	sep; 
}

sub rllvrslot9 {
	sep; 
	if ($rllvrreelspin == 0) {
		print colored('   |-X',"$rllvrcolor11 on_$rllvrcolor9"); print colored('-|   ',"$rllvrcolor12 on_$rllvrcolor9");
	} elsif ($rllvrreelspin == 1) {
		print colored('   |-X-|   ',"$rllvrcolor12 on_$rllvrcolor9");
	} else {
		print colored('           ',"$rllvrcolor12 on_$rllvrcolor9");
	}
	sep; 
}

sub rllvrslot10 {
	sep; 
	if ($rllvrreelspin == 0) {
		print colored('   \\/',"$rllvrcolor11 on_$rllvrcolor9"); print colored('|\\/   ',"$rllvrcolor12 on_$rllvrcolor9");
	} elsif ($rllvrreelspin == 1) {
		print colored('   \\/|\\/   ',"$rllvrcolor12 on_$rllvrcolor9");
	} else {
		print colored('           ',"$rllvrcolor12 on_$rllvrcolor9");
	}
	sep; 
}

sub rllvrwheel {
	if ($rllvrwinnbr == 38) {
		$rllvrslotA = ' 9 '; $rllvrcolorA = $rllvrcolor3;
		$rllvrslotB = '2 8'; $rllvrcolorB = $rllvrcolor2;
		$rllvrslotC = ' 0 '; $rllvrcolorC = $rllvrcolor1;
		$rllvrslotD = ' 2 '; $rllvrcolorD = $rllvrcolor2;
		$rllvrslotE = '1 4'; $rllvrcolorE = $rllvrcolor3;
	} elsif ($rllvrwinnbr == 28) {
		$rllvrslotA = '2 6'; $rllvrcolorA = $rllvrcolor2;
		$rllvrslotB = ' 9 '; $rllvrcolorB = $rllvrcolor3;
		$rllvrslotC = '2 8'; $rllvrcolorC = $rllvrcolor2;
		$rllvrslotD = ' 0 '; $rllvrcolorD = $rllvrcolor1;
		$rllvrslotE = ' 2 '; $rllvrcolorE = $rllvrcolor2;
	} elsif ($rllvrwinnbr == 9) {
		$rllvrslotA = '3 0'; $rllvrcolorA = $rllvrcolor3;
		$rllvrslotB = '2 6'; $rllvrcolorB = $rllvrcolor2;
		$rllvrslotC = ' 9 '; $rllvrcolorC = $rllvrcolor3;
		$rllvrslotD = '2 8'; $rllvrcolorD = $rllvrcolor2;
		$rllvrslotE = ' 0 '; $rllvrcolorE = $rllvrcolor1;
	} elsif ($rllvrwinnbr == 26) {
		$rllvrslotA = '1 1'; $rllvrcolorA = $rllvrcolor2;
		$rllvrslotB = '3 0'; $rllvrcolorB = $rllvrcolor3;
		$rllvrslotC = '2 6'; $rllvrcolorC = $rllvrcolor2;
		$rllvrslotD = ' 9 '; $rllvrcolorD = $rllvrcolor3;
		$rllvrslotE = '2 8'; $rllvrcolorE = $rllvrcolor2;
	} elsif ($rllvrwinnbr == 30) {
		$rllvrslotA = ' 7 '; $rllvrcolorA = $rllvrcolor3;	
		$rllvrslotB = '1 1'; $rllvrcolorB = $rllvrcolor2;
		$rllvrslotC = '3 0'; $rllvrcolorC = $rllvrcolor3;
		$rllvrslotD = '2 6'; $rllvrcolorD = $rllvrcolor2;
		$rllvrslotE = ' 9 '; $rllvrcolorE = $rllvrcolor3;
	} elsif ($rllvrwinnbr == 11) {
		$rllvrslotA = '2 0'; $rllvrcolorA = $rllvrcolor2;
		$rllvrslotB = ' 7 '; $rllvrcolorB = $rllvrcolor3;	
		$rllvrslotC = '1 1'; $rllvrcolorC = $rllvrcolor2;
		$rllvrslotD = '3 0'; $rllvrcolorD = $rllvrcolor3;
		$rllvrslotE = '2 6'; $rllvrcolorE = $rllvrcolor2;
	} elsif ($rllvrwinnbr == 7) {
		$rllvrslotA = '3 2'; $rllvrcolorA = $rllvrcolor3;
		$rllvrslotB = '2 0'; $rllvrcolorB = $rllvrcolor2;
		$rllvrslotC = ' 7 '; $rllvrcolorC = $rllvrcolor3;	
		$rllvrslotD = '1 1'; $rllvrcolorD = $rllvrcolor2;
		$rllvrslotE = '3 0'; $rllvrcolorE = $rllvrcolor3;
	} elsif ($rllvrwinnbr == 20) {
		$rllvrslotA = '1 7'; $rllvrcolorA = $rllvrcolor2;
		$rllvrslotB = '3 2'; $rllvrcolorB = $rllvrcolor3;
		$rllvrslotC = '2 0'; $rllvrcolorC = $rllvrcolor2;
		$rllvrslotD = ' 7 '; $rllvrcolorD = $rllvrcolor3;	
		$rllvrslotE = '1 1'; $rllvrcolorE = $rllvrcolor2;
	} elsif ($rllvrwinnbr == 32) {
		$rllvrslotA = ' 5 '; $rllvrcolorA = $rllvrcolor3;
		$rllvrslotB = '1 7'; $rllvrcolorB = $rllvrcolor2;
		$rllvrslotC = '3 2'; $rllvrcolorC = $rllvrcolor3;
		$rllvrslotD = '2 0'; $rllvrcolorD = $rllvrcolor2;
		$rllvrslotE = ' 7 '; $rllvrcolorE = $rllvrcolor3;
	} elsif ($rllvrwinnbr == 17) {
		$rllvrslotA = '2 2'; $rllvrcolorA = $rllvrcolor2;
		$rllvrslotB = ' 5 '; $rllvrcolorB = $rllvrcolor3;
		$rllvrslotC = '1 7'; $rllvrcolorC = $rllvrcolor2;
		$rllvrslotD = '3 2'; $rllvrcolorD = $rllvrcolor3;
		$rllvrslotE = '2 0'; $rllvrcolorE = $rllvrcolor2;
	} elsif ($rllvrwinnbr == 5) {
		$rllvrslotA = '3 4'; $rllvrcolorA = $rllvrcolor3;
		$rllvrslotB = '2 2'; $rllvrcolorB = $rllvrcolor2;
		$rllvrslotC = ' 5 '; $rllvrcolorC = $rllvrcolor3;
		$rllvrslotD = '1 7'; $rllvrcolorD = $rllvrcolor2;
		$rllvrslotE = '3 2'; $rllvrcolorE = $rllvrcolor3;
	} elsif ($rllvrwinnbr == 22) {
		$rllvrslotA = '1 5'; $rllvrcolorA = $rllvrcolor2;
		$rllvrslotB = '3 4'; $rllvrcolorB = $rllvrcolor3;
		$rllvrslotC = '2 2'; $rllvrcolorC = $rllvrcolor2;
		$rllvrslotD = ' 5 '; $rllvrcolorD = $rllvrcolor3;
		$rllvrslotE = '1 7'; $rllvrcolorE = $rllvrcolor2;
	} elsif ($rllvrwinnbr == 34) {
		$rllvrslotA = ' 3 '; $rllvrcolorA = $rllvrcolor3;
		$rllvrslotB = '1 5'; $rllvrcolorB = $rllvrcolor2;
		$rllvrslotC = '3 4'; $rllvrcolorC = $rllvrcolor3;
		$rllvrslotD = '2 2'; $rllvrcolorD = $rllvrcolor2;
		$rllvrslotE = ' 5 '; $rllvrcolorE = $rllvrcolor3;
	} elsif ($rllvrwinnbr == 15) {
		$rllvrslotA = '2 4'; $rllvrcolorA = $rllvrcolor2;
		$rllvrslotB = ' 3 '; $rllvrcolorB = $rllvrcolor3;
		$rllvrslotC = '1 5'; $rllvrcolorC = $rllvrcolor2;
		$rllvrslotD = '3 4'; $rllvrcolorD = $rllvrcolor3;
		$rllvrslotE = '2 2'; $rllvrcolorE = $rllvrcolor2;
	} elsif ($rllvrwinnbr == 3) {
		$rllvrslotA = '3 6'; $rllvrcolorA = $rllvrcolor3;
		$rllvrslotB = '2 4'; $rllvrcolorB = $rllvrcolor2;
		$rllvrslotC = ' 3 '; $rllvrcolorC = $rllvrcolor3;
		$rllvrslotD = '1 5'; $rllvrcolorD = $rllvrcolor2;
		$rllvrslotE = '3 4'; $rllvrcolorE = $rllvrcolor3;
	} elsif ($rllvrwinnbr == 24) {
		$rllvrslotA = '1 3'; $rllvrcolorA = $rllvrcolor2;
		$rllvrslotB = '3 6'; $rllvrcolorB = $rllvrcolor3;
		$rllvrslotC = '2 4'; $rllvrcolorC = $rllvrcolor2;
		$rllvrslotD = ' 3 '; $rllvrcolorD = $rllvrcolor3;
		$rllvrslotE = '1 5'; $rllvrcolorE = $rllvrcolor2;
	} elsif ($rllvrwinnbr == 36) {
		$rllvrslotA = ' 1 '; $rllvrcolorA = $rllvrcolor3;
		$rllvrslotB = '1 3'; $rllvrcolorB = $rllvrcolor2;
		$rllvrslotC = '3 6'; $rllvrcolorC = $rllvrcolor3;
		$rllvrslotD = '2 4'; $rllvrcolorD = $rllvrcolor2;
		$rllvrslotE = ' 3 '; $rllvrcolorE = $rllvrcolor3;
	} elsif ($rllvrwinnbr == 13) {
		$rllvrslotA = '0 0'; $rllvrcolorA = $rllvrcolor1;
		$rllvrslotB = ' 1 '; $rllvrcolorB = $rllvrcolor3;
		$rllvrslotC = '1 3'; $rllvrcolorC = $rllvrcolor2;
		$rllvrslotD = '3 6'; $rllvrcolorD = $rllvrcolor3;
		$rllvrslotE = '2 4'; $rllvrcolorE = $rllvrcolor2;
	} elsif ($rllvrwinnbr == 1) {
		$rllvrslotA = '2 7'; $rllvrcolorA = $rllvrcolor3;
		$rllvrslotB = '0 0'; $rllvrcolorB = $rllvrcolor1;
		$rllvrslotC = ' 1 '; $rllvrcolorC = $rllvrcolor3;
		$rllvrslotD = '1 3'; $rllvrcolorD = $rllvrcolor2;
		$rllvrslotE = '3 6'; $rllvrcolorE = $rllvrcolor3;
	} elsif ($rllvrwinnbr == 37) {
		$rllvrslotA = '1 0'; $rllvrcolorA = $rllvrcolor2;
		$rllvrslotB = '2 7'; $rllvrcolorB = $rllvrcolor3;
		$rllvrslotC = '0 0'; $rllvrcolorC = $rllvrcolor1;
		$rllvrslotD = ' 1 '; $rllvrcolorD = $rllvrcolor3;
		$rllvrslotE = '1 3'; $rllvrcolorE = $rllvrcolor2;
	} elsif ($rllvrwinnbr == 27) {
		$rllvrslotA = '2 5'; $rllvrcolorA = $rllvrcolor3;
		$rllvrslotB = '1 0'; $rllvrcolorB = $rllvrcolor2;
		$rllvrslotC = '2 7'; $rllvrcolorC = $rllvrcolor3;
		$rllvrslotD = '0 0'; $rllvrcolorD = $rllvrcolor1;
		$rllvrslotE = ' 1 '; $rllvrcolorE = $rllvrcolor3;
	} elsif ($rllvrwinnbr == 10) {
		$rllvrslotA = '2 9'; $rllvrcolorA = $rllvrcolor2;
		$rllvrslotB = '2 5'; $rllvrcolorB = $rllvrcolor3;
		$rllvrslotC = '1 0'; $rllvrcolorC = $rllvrcolor2;
		$rllvrslotD = '2 7'; $rllvrcolorD = $rllvrcolor3;
		$rllvrslotE = '0 0'; $rllvrcolorE = $rllvrcolor1;
	} elsif ($rllvrwinnbr == 25) {
		$rllvrslotA = '1 2'; $rllvrcolorA = $rllvrcolor3;
		$rllvrslotB = '2 9'; $rllvrcolorB = $rllvrcolor2;
		$rllvrslotC = '2 5'; $rllvrcolorC = $rllvrcolor3;
		$rllvrslotD = '1 0'; $rllvrcolorD = $rllvrcolor2;
		$rllvrslotE = '2 7'; $rllvrcolorE = $rllvrcolor3;
	} elsif ($rllvrwinnbr == 29) {
		$rllvrslotA = ' 8 '; $rllvrcolorA = $rllvrcolor2;
		$rllvrslotB = '1 2'; $rllvrcolorB = $rllvrcolor3;
		$rllvrslotC = '2 9'; $rllvrcolorC = $rllvrcolor2;
		$rllvrslotD = '2 5'; $rllvrcolorD = $rllvrcolor3;
		$rllvrslotE = '1 0'; $rllvrcolorE = $rllvrcolor2;
	} elsif ($rllvrwinnbr == 12) {
		$rllvrslotA = '1 9'; $rllvrcolorA = $rllvrcolor3;
		$rllvrslotB = ' 8 '; $rllvrcolorB = $rllvrcolor2;
		$rllvrslotC = '1 2'; $rllvrcolorC = $rllvrcolor3;
		$rllvrslotD = '2 9'; $rllvrcolorD = $rllvrcolor2;
		$rllvrslotE = '2 5'; $rllvrcolorE = $rllvrcolor3;
	} elsif ($rllvrwinnbr == 8) {
		$rllvrslotA = '3 1'; $rllvrcolorA = $rllvrcolor2;
		$rllvrslotB = '1 9'; $rllvrcolorB = $rllvrcolor3;
		$rllvrslotC = ' 8 '; $rllvrcolorC = $rllvrcolor2;
		$rllvrslotD = '1 2'; $rllvrcolorD = $rllvrcolor3;
		$rllvrslotE = '2 9'; $rllvrcolorE = $rllvrcolor2;
	} elsif ($rllvrwinnbr == 19) {
		$rllvrslotA = '1 8'; $rllvrcolorA = $rllvrcolor3;
		$rllvrslotB = '3 1'; $rllvrcolorB = $rllvrcolor2;
		$rllvrslotC = '1 9'; $rllvrcolorC = $rllvrcolor3;
		$rllvrslotD = ' 8 '; $rllvrcolorD = $rllvrcolor2;
		$rllvrslotE = '1 2'; $rllvrcolorE = $rllvrcolor3;
	} elsif ($rllvrwinnbr == 31) {
		$rllvrslotA = ' 6 '; $rllvrcolorA = $rllvrcolor2;
		$rllvrslotB = '1 8'; $rllvrcolorB = $rllvrcolor3;
		$rllvrslotC = '3 1'; $rllvrcolorC = $rllvrcolor2;
		$rllvrslotD = '1 9'; $rllvrcolorD = $rllvrcolor3;
		$rllvrslotE = ' 8 '; $rllvrcolorE = $rllvrcolor2;
	} elsif ($rllvrwinnbr == 18) {
		$rllvrslotA = '2 1'; $rllvrcolorA = $rllvrcolor3;
		$rllvrslotB = ' 6 '; $rllvrcolorB = $rllvrcolor2;
		$rllvrslotC = '1 8'; $rllvrcolorC = $rllvrcolor3;
		$rllvrslotD = '3 1'; $rllvrcolorD = $rllvrcolor2;
		$rllvrslotE = '1 9'; $rllvrcolorE = $rllvrcolor3;
	} elsif ($rllvrwinnbr == 6) {
		$rllvrslotA = '3 3'; $rllvrcolorA = $rllvrcolor2;
		$rllvrslotB = '2 1'; $rllvrcolorB = $rllvrcolor3;
		$rllvrslotC = ' 6 '; $rllvrcolorC = $rllvrcolor2;
		$rllvrslotD = '1 8'; $rllvrcolorD = $rllvrcolor3;
		$rllvrslotE = '3 1'; $rllvrcolorE = $rllvrcolor2;
	} elsif ($rllvrwinnbr == 21) {
		$rllvrslotA = '1 6'; $rllvrcolorA = $rllvrcolor3;
		$rllvrslotB = '3 3'; $rllvrcolorB = $rllvrcolor2;
		$rllvrslotC = '2 1'; $rllvrcolorC = $rllvrcolor3;
		$rllvrslotD = ' 6 '; $rllvrcolorD = $rllvrcolor2;
		$rllvrslotE = '1 8'; $rllvrcolorE = $rllvrcolor3;
	} elsif ($rllvrwinnbr == 33) {
		$rllvrslotA = ' 4 '; $rllvrcolorA = $rllvrcolor2;
		$rllvrslotB = '1 6'; $rllvrcolorB = $rllvrcolor3;
		$rllvrslotC = '3 3'; $rllvrcolorC = $rllvrcolor2;
		$rllvrslotD = '2 1'; $rllvrcolorD = $rllvrcolor3;
		$rllvrslotE = ' 6 '; $rllvrcolorE = $rllvrcolor2;
	} elsif ($rllvrwinnbr == 16) {
		$rllvrslotA = '2 3'; $rllvrcolorA = $rllvrcolor3;
		$rllvrslotB = ' 4 '; $rllvrcolorB = $rllvrcolor2;
		$rllvrslotC = '1 6'; $rllvrcolorC = $rllvrcolor3;
		$rllvrslotD = '3 3'; $rllvrcolorD = $rllvrcolor2;
		$rllvrslotE = '2 1'; $rllvrcolorE = $rllvrcolor3;
	} elsif ($rllvrwinnbr == 4) {
		$rllvrslotA = '3 5'; $rllvrcolorA = $rllvrcolor2;
		$rllvrslotB = '2 3'; $rllvrcolorB = $rllvrcolor3;
		$rllvrslotC = ' 4 '; $rllvrcolorC = $rllvrcolor2;
		$rllvrslotD = '1 6'; $rllvrcolorD = $rllvrcolor3;
		$rllvrslotE = '3 3'; $rllvrcolorE = $rllvrcolor2;
	} elsif ($rllvrwinnbr == 23) {
		$rllvrslotA = '1 4'; $rllvrcolorA = $rllvrcolor3;
		$rllvrslotB = '3 5'; $rllvrcolorB = $rllvrcolor2;
		$rllvrslotC = '2 3'; $rllvrcolorC = $rllvrcolor3;
		$rllvrslotD = ' 4 '; $rllvrcolorD = $rllvrcolor2;
		$rllvrslotE = '1 6'; $rllvrcolorE = $rllvrcolor3;
	} elsif ($rllvrwinnbr == 35) {
		$rllvrslotA = ' 2 '; $rllvrcolorA = $rllvrcolor2;
		$rllvrslotB = '1 4'; $rllvrcolorB = $rllvrcolor3;
		$rllvrslotC = '3 5'; $rllvrcolorC = $rllvrcolor2;
		$rllvrslotD = '2 3'; $rllvrcolorD = $rllvrcolor3;
		$rllvrslotE = ' 4 '; $rllvrcolorE = $rllvrcolor2;
	} elsif ($rllvrwinnbr == 14) {
		$rllvrslotA = ' 0 '; $rllvrcolorA = $rllvrcolor1;
		$rllvrslotB = ' 2 '; $rllvrcolorB = $rllvrcolor2;
		$rllvrslotC = '1 4'; $rllvrcolorC = $rllvrcolor3;
		$rllvrslotD = '3 5'; $rllvrcolorD = $rllvrcolor2;
		$rllvrslotE = '2 3'; $rllvrcolorE = $rllvrcolor3;
	} elsif ($rllvrwinnbr == 2) {
		$rllvrslotA = '2 8'; $rllvrcolorA = $rllvrcolor2;
		$rllvrslotB = ' 0 '; $rllvrcolorB = $rllvrcolor1;
		$rllvrslotC = ' 2 '; $rllvrcolorC = $rllvrcolor2;
		$rllvrslotD = '1 4'; $rllvrcolorD = $rllvrcolor3;
		$rllvrslotE = '3 5'; $rllvrcolorE = $rllvrcolor2;
	} else {
		$rllvrslotA = '0?0'; $rllvrcolorA = $rllvrcolor2;
		$rllvrslotB = '?0?'; $rllvrcolorB = $rllvrcolor3;
		$rllvrslotC = '0?0'; $rllvrcolorC = $rllvrcolor1;
		$rllvrslotD = '?0?'; $rllvrcolorD = $rllvrcolor3;
		$rllvrslotE = '0?0'; $rllvrcolorE = $rllvrcolor2;	
	}
	
	if ($rllvrcolorA eq $rllvrcolor2) {
		$rllvrcolorAb = $rllvrcolor2b;
	} elsif ($rllvrcolorA eq $rllvrcolor3) {
		$rllvrcolorAb = $rllvrcolor3b;
	} elsif ($rllvrcolorA eq $rllvrcolor1) {
		$rllvrcolorAb = $rllvrcolor4;
	}
	
	if ($rllvrcolorB eq $rllvrcolor2) {
		$rllvrcolorBb = $rllvrcolor2b;
	} elsif ($rllvrcolorB eq $rllvrcolor3) {
		$rllvrcolorBb = $rllvrcolor3b;
	} elsif ($rllvrcolorB eq $rllvrcolor1) {
		$rllvrcolorBb = $rllvrcolor4;
	}
	
	if ($rllvrcolorC eq $rllvrcolor2) {
		$rllvrcolorCb = $rllvrcolor2b;
	} elsif ($rllvrcolorC eq $rllvrcolor3) {
		$rllvrcolorCb = $rllvrcolor3b;
	} elsif ($rllvrcolorC eq $rllvrcolor1) {
		$rllvrcolorCb = $rllvrcolor4;
	}
	
	if ($rllvrcolorD eq $rllvrcolor2) {
		$rllvrcolorDb = $rllvrcolor2b;
	} elsif ($rllvrcolorD eq $rllvrcolor3) {
		$rllvrcolorDb = $rllvrcolor3b;
	} elsif ($rllvrcolorD eq $rllvrcolor1) {
		$rllvrcolorDb = $rllvrcolor4;
	}
	
	if ($rllvrcolorE eq $rllvrcolor2) {
		$rllvrcolorEb = $rllvrcolor2b;
	} elsif ($rllvrcolorE eq $rllvrcolor3) {
		$rllvrcolorEb = $rllvrcolor3b;
	} elsif ($rllvrcolorE eq $rllvrcolor1) {
		$rllvrcolorEb = $rllvrcolor4;
	}
}

sub rllvrprintmain {
	rllvrmedian1(); print"\n";
	rllvrcolorcA(); rllvrslot5(); rllvrslot4(); rllvrslot1(); rllvrslot4(); rllvrslot7(); rllvrslot5(); rllvrstatusbar2(); print"\n";
	rllvrslot5(); rllvrslot4(); rllvrslot2(); rllvrslot4(); rllvrslot7(); rllvrslot5(); rllvrstatusbar3(); print"\n";
	rllvrslot5(); rllvrslot4(); rllvrslot1(); rllvrslot4(); rllvrslot7(); rllvrslot5(); rllvrstatusbar4(); print"\n";
	rllvrslot5(); rllvrslot4(); rllvrslot1(); rllvrslot4(); rllvrslot7(); rllvrslot5(); rllvrstatusbar5(); print"\n";
	rllvrslot5(); rllvrslot3(); rllvrslot6(); rllvrslot5();rllvrspace1(); rllvrb000(); rllvrstatusbar6(); print"\n";

	rllvrcolorcB(); rllvrslot5(); rllvrslot4(); rllvrslot1(); rllvrslot4(); rllvrslot7(); rllvrslot5(); rllvrspace1(); rllvrb00(); rllvrstatusbar7(); print"\n";
	rllvrslot5(); rllvrslot4(); rllvrslot1(); rllvrslot4(); rllvrslot7();  rllvrslot5(); rllvrspace1(); rllvrb0(); rllvrstatusbar8(); print"\n";
	rllvrslot5(); rllvrslot4(); rllvrslot2(); rllvrslot4(); rllvrslot7(); rllvrslot5(); rllvrspace1(); rllvrb1(); rllvrstatusbar9(); print"\n";
	rllvrslot5(); rllvrslot4(); rllvrslot1(); rllvrslot4(); rllvrslot7(); rllvrslot5(); rllvrspace1(); rllvrb2(); rllvrstatusbar10(); print"\n";
	rllvrslot5(); rllvrslot4(); rllvrslot1(); rllvrslot4(); rllvrslot7(); rllvrslot5(); rllvrspace1(); rllvrb3(); rllvrstatusbar11(); print"\n";
	rllvrslot5(); rllvrslot3(); rllvrslot6();  rllvrslot5(); rllvrspace1(); rllvrb0(); rllvrstatusbar12(); print"\n";

	rllvrcolorcC(); rllvrslot5(); rllvrslot4(); rllvrslot1(); rllvrslot4(); rllvrslot7(); rllvrslot5(); rllvrspace1(); rllvrb4(); rllvrstatusbar13(); print"\n";
	rllvrslot5(); rllvrslot4(); rllvrslot1(); rllvrslot4(); rllvrslot8(); rllvrslot5(); rllvrspace1(); rllvrb5(); rllvrstatusbar14(); print"\n";
	rllvrslot5(); rllvrslot4(); rllvrslot2(); rllvrslot4(); rllvrslot9(); rllvrslot5();  rllvrspace1(); rllvrb6(); rllvrstatusbar15(); print"\n";
	rllvrslot5(); rllvrslot4(); rllvrslot1(); rllvrslot4(); rllvrslot10(); rllvrslot5(); rllvrspace1(); rllvrb0(); rllvrstatusbar16(); print"\n";
	rllvrslot5(); rllvrslot4(); rllvrslot1(); rllvrslot4(); rllvrslot7(); rllvrslot5(); rllvrspace1(); rllvrb7(); rllvrstatusbar17(); print"\n";
	rllvrslot5(); rllvrslot3(); rllvrslot6(); rllvrslot5(); rllvrspace1(); rllvrb8(); rllvrstatusbar18(); print"\n";

	rllvrcolorcD(); rllvrslot5(); rllvrslot4(); rllvrslot1(); rllvrslot4(); rllvrslot7(); rllvrslot5(); rllvrspace1(); rllvrb9(); rllvrstatusbar19(); print"\n";
	rllvrslot5(); rllvrslot4(); rllvrslot1(); rllvrslot4(); rllvrslot7(); rllvrslot5(); rllvrspace1(); rllvrb0(); rllvrstatusbar20(); print"\n";
	rllvrslot5(); rllvrslot4(); rllvrslot2(); rllvrslot4(); rllvrslot7(); rllvrslot5(); rllvrspace1(); rllvrb10(); rllvrstatusbar21(); print"\n";
	rllvrslot5(); rllvrslot4(); rllvrslot1(); rllvrslot4(); rllvrslot7(); rllvrslot5(); rllvrspace1(); rllvrb11(); rllvrstatusbar22(); print"\n";
	rllvrslot5(); rllvrslot4(); rllvrslot1(); rllvrslot4(); rllvrslot7(); rllvrslot5(); rllvrspace1(); rllvrb12(); rllvrstatusbar23(); print"\n";
	rllvrslot5(); rllvrslot3(); rllvrslot6(); rllvrslot5(); rllvrspace1(); rllvrb0(); rllvrstatusbar24(); print"\n";

	rllvrcolorcE(); rllvrslot5(); rllvrslot4(); rllvrslot1(); rllvrslot4(); rllvrslot7(); rllvrslot5(); rllvrspace1(); rllvrb00000(); rllvrstatusbar25(); print"\n";
	rllvrslot5(); rllvrslot4(); rllvrslot1(); rllvrslot4(); rllvrslot7(); rllvrslot5(); rllvrspace1(); rllvrb0000(); rllvrstatusbar26(); print"\n";
	rllvrslot5(); rllvrslot4(); rllvrslot2(); rllvrslot4(); rllvrslot7(); rllvrslot5(); rllvrstatusbar3();print"\n";
	rllvrslot5(); rllvrslot4(); rllvrslot1(); rllvrslot4(); rllvrslot7(); rllvrslot5(); rllvrstatusbar(); print"\n";
	rllvrslot5(); rllvrslot4(); rllvrslot1(); rllvrslot4(); rllvrslot7(); rllvrslot5(); rllvrmedian3(); print"\n";
	rllvrmedian2(); STDOUT->flush();
}

sub rllvrmedian1 { 
	print colored('/------------------------------------------------------------------------------\\',"$rllvrcolor8 on_$rllvrcolor7");
}

sub rllvrmedian2 { 
	print colored('\\----------------------/',"$rllvrcolor8 on_$rllvrcolor7");
}

sub rllvrmedian3 { 
	print colored('-------------------------------------------------------/',"$rllvrcolor8 on_$rllvrcolor7");
}

sub rllvrstatusbar {
	print colored('      WINNINGS ',"$rllvrcolor8 on_$rllvrcolor7");
	rllvrwinnings();
	print colored('     TOTAL FUNDS ',"$rllvrcolor8 on_$rllvrcolor7");
	rllvrtotal();
	print colored('   ',"$rllvrcolor8 on_$rllvrcolor7");
	rllvrslot5();
}

sub rllvrstatusbar2 {
	if ($rllvrsetup == 0) {
	print colored('         Real Vegas Roulette     ',"$rllvrcolor15 on_$rllvrcolor7");
	} else {
	print colored('        Roulette De Americana    ',"$rllvrcolor15 on_$rllvrcolor7");
	}
	print colored('       BET ',"$rllvrcolor8 on_$rllvrcolor7");
	rllvrbet();
	print colored(' ',"$rllvrcolor8 on_$rllvrcolor7");
	rllvrslot5();
}

sub rllvrstatusbar3 {
                                                                              #
	print colored('                                                       |',"$rllvrcolor8 on_$rllvrcolor7");
}

sub rllvrstatusbar4 {
                                                                              #
	print colored('    P = PLAY   B = CHANGE BET  N = CHANGE NUMBERS      |',"$rllvrcolor8 on_$rllvrcolor7");
}

sub rllvrstatusbar5 {
                                                                              #
	print colored(' C = RETURN TO CASINO MENU   ',"$rllvrcolor8 on_$rllvrcolor7");
	print colored('/-------------------------|',"$rllvrcolor20 on_$rllvrcolor21");
}

sub rllvrstatusbar6 {
	print colored('   ',"$rllvrcolor8 on_$rllvrcolor7");
	print colored('//',"$rllvrcolor20 on_$rllvrcolor21");
	print colored("$rllvrcomp1","$rllvrcolor22 on_$rllvrcolor23");
	print colored('|',"$rllvrcolor20 on_$rllvrcolor21");
}

sub rllvrstatusbar7 {
	print colored('   ',"$rllvrcolor8 on_$rllvrcolor7");
	print colored('|',"$rllvrcolor20 on_$rllvrcolor21");
	print colored("$rllvrcomp2","$rllvrcolor24 on_$rllvrcolor25");
	print colored('|',"$rllvrcolor20 on_$rllvrcolor21");
}

sub rllvrstatusbar8 {
	print colored('   ',"$rllvrcolor8 on_$rllvrcolor7");
	print colored('|',"$rllvrcolor20 on_$rllvrcolor21");
	print colored("$rllvrcomp3","$rllvrcolor22 on_$rllvrcolor23");
	print colored('|',"$rllvrcolor20 on_$rllvrcolor21");
}

sub rllvrstatusbar9 {
	print colored('   ',"$rllvrcolor8 on_$rllvrcolor7");
	print colored('|',"$rllvrcolor20 on_$rllvrcolor21");
	print colored("$rllvrcomp4","$rllvrcolor24 on_$rllvrcolor25");
	print colored('|',"$rllvrcolor20 on_$rllvrcolor21");
}

sub rllvrstatusbar10 {
	print colored('   ',"$rllvrcolor8 on_$rllvrcolor7");
	print colored('|',"$rllvrcolor20 on_$rllvrcolor21");
	print colored("$rllvrcomp5","$rllvrcolor22 on_$rllvrcolor23");
	print colored('|',"$rllvrcolor20 on_$rllvrcolor21");
}

sub rllvrstatusbar11 {
	print colored('   ',"$rllvrcolor8 on_$rllvrcolor7");
	print colored('|',"$rllvrcolor20 on_$rllvrcolor21");
	print colored("$rllvrcomp6","$rllvrcolor24 on_$rllvrcolor25");
	print colored('|',"$rllvrcolor20 on_$rllvrcolor21");
}

sub rllvrstatusbar12 {
	print colored('   ',"$rllvrcolor8 on_$rllvrcolor7");
	print colored('|',"$rllvrcolor20 on_$rllvrcolor21");
	print colored("$rllvrcomp7","$rllvrcolor22 on_$rllvrcolor23");
	print colored('|',"$rllvrcolor20 on_$rllvrcolor21");
}

sub rllvrstatusbar13 {
	print colored('   ',"$rllvrcolor8 on_$rllvrcolor7");
	print colored('|',"$rllvrcolor20 on_$rllvrcolor21");
	print colored("$rllvrcomp8","$rllvrcolor24 on_$rllvrcolor25");
	print colored('|',"$rllvrcolor20 on_$rllvrcolor21");
}

sub rllvrstatusbar14 {
	print colored('   ',"$rllvrcolor8 on_$rllvrcolor7");
	print colored('|',"$rllvrcolor20 on_$rllvrcolor21");
	print colored("$rllvrcomp9","$rllvrcolor22 on_$rllvrcolor23");
	print colored('|',"$rllvrcolor20 on_$rllvrcolor21");
}

sub rllvrstatusbar15 {
	print colored('   ',"$rllvrcolor8 on_$rllvrcolor7");
	print colored('|',"$rllvrcolor20 on_$rllvrcolor21");
	print colored("$rllvrcomp10","$rllvrcolor24 on_$rllvrcolor25");
	print colored('|',"$rllvrcolor20 on_$rllvrcolor21");
}

sub rllvrstatusbar16 {
	print colored('   ',"$rllvrcolor8 on_$rllvrcolor7");
	print colored('|',"$rllvrcolor20 on_$rllvrcolor21");
	print colored("$rllvrcomp11","$rllvrcolor22 on_$rllvrcolor23");
	print colored('|',"$rllvrcolor20 on_$rllvrcolor21");
}

sub rllvrstatusbar17 {
	print colored('   ',"$rllvrcolor8 on_$rllvrcolor7");
	print colored('|',"$rllvrcolor20 on_$rllvrcolor21");
	print colored("$rllvrcomp12","$rllvrcolor24 on_$rllvrcolor25");
	print colored('|',"$rllvrcolor20 on_$rllvrcolor21");
}

sub rllvrstatusbar18 {
	print colored('   ',"$rllvrcolor8 on_$rllvrcolor7");
	print colored('|',"$rllvrcolor20 on_$rllvrcolor21");
	print colored("$rllvrcomp13","$rllvrcolor22 on_$rllvrcolor23");
	print colored('|',"$rllvrcolor20 on_$rllvrcolor21");
}

sub rllvrstatusbar19 {
	print colored('   ',"$rllvrcolor8 on_$rllvrcolor7");
	print colored('|',"$rllvrcolor20 on_$rllvrcolor21");
	print colored("$rllvrcomp14","$rllvrcolor24 on_$rllvrcolor25");
	print colored('|',"$rllvrcolor20 on_$rllvrcolor21");
}

sub rllvrstatusbar20 {
	print colored('   ',"$rllvrcolor8 on_$rllvrcolor7");
	print colored('|',"$rllvrcolor20 on_$rllvrcolor21");
	print colored("$rllvrcomp15","$rllvrcolor22 on_$rllvrcolor23");
	print colored('|',"$rllvrcolor20 on_$rllvrcolor21");
}

sub rllvrstatusbar21 {
	print colored('   ',"$rllvrcolor8 on_$rllvrcolor7");
	print colored('|',"$rllvrcolor20 on_$rllvrcolor21");
	print colored("$rllvrcomp16","$rllvrcolor24 on_$rllvrcolor25");
	print colored('|',"$rllvrcolor20 on_$rllvrcolor21");
}

sub rllvrstatusbar22 {
	print colored('   ',"$rllvrcolor8 on_$rllvrcolor7");
	print colored('|',"$rllvrcolor20 on_$rllvrcolor21");
	print colored("$rllvrcomp17","$rllvrcolor22 on_$rllvrcolor23");
	print colored('|',"$rllvrcolor20 on_$rllvrcolor21");
}

sub rllvrstatusbar23 {
	print colored('   ',"$rllvrcolor8 on_$rllvrcolor7");
	print colored('|',"$rllvrcolor20 on_$rllvrcolor21");
	print colored("$rllvrcomp18","$rllvrcolor24 on_$rllvrcolor25");
	print colored('|',"$rllvrcolor20 on_$rllvrcolor21");
}

sub rllvrstatusbar24 {
	print colored('   ',"$rllvrcolor8 on_$rllvrcolor7");
	print colored('|',"$rllvrcolor20 on_$rllvrcolor21");
	print colored("$rllvrcomp19","$rllvrcolor22 on_$rllvrcolor23");
	print colored('|',"$rllvrcolor20 on_$rllvrcolor21");
}

sub rllvrstatusbar25 {
	print colored('   ',"$rllvrcolor8 on_$rllvrcolor7");
	print colored('\\\\',"$rllvrcolor20 on_$rllvrcolor21");
	print colored("$rllvrcomp20","$rllvrcolor24 on_$rllvrcolor25");
	print colored('|',"$rllvrcolor20 on_$rllvrcolor21");
}

sub rllvrstatusbar26 {                                                                              #
	print colored('    ',"$rllvrcolor8 on_$rllvrcolor7");
	print colored('\-------------------------|',"$rllvrcolor20 on_$rllvrcolor21");
}

sub rllvrstdcomp {
	if ($rllvrsetup == 0) {
	$rllvrcomp1 = '                         ';
	$rllvrcomp2 = '  Single Numbers Pay  36X ';
	$rllvrcomp3 = '                          ';
	$rllvrcomp4 = '  Columns Pay          3X ';
	$rllvrcomp5 = '                          ';
	$rllvrcomp6 = '  Even / Odd Pays      2X ';
	$rllvrcomp7 = '                          ';
		if ($rllvrfuturecarlo == 1) {
		$rllvrcomp8 = '  Magenta / Blue Pays  2X ';
		} else { 
		$rllvrcomp8 = '  Red / Black Pays     2X ';
		}
	$rllvrcomp9 = '                          ';
	$rllvrcomp10 = '  Double Thirds Pay  1.5X ';
	$rllvrcomp11 = '                          ';
	$rllvrcomp12 = '  Triple Fourths Pay 1.3X ';
	$rllvrcomp13 = '                          ';
	$rllvrcomp14 = '  Groups Pay           4X ';
	$rllvrcomp15 = '                          ';
	$rllvrcomp16 = '  Lines Pay           12X ';
	$rllvrcomp17 = '                          ';
	$rllvrcomp18 = '  Powers of 2 Pay      7X ';
	$rllvrcomp19 = '                          ';
	$rllvrcomp20 = ' Zeroes Pay          18X ';
	} else {
	$rllvrcomp1 = '                         ';
	$rllvrcomp2 = '  Single Numbers Pay  36X ';
	$rllvrcomp3 = '                          ';
	$rllvrcomp4 = '  Columns Pay          3X ';
	$rllvrcomp5 = '                          ';
	$rllvrcomp6 = '  Odds or Evens Pays   2X ';
	$rllvrcomp7 = '                          ';
	$rllvrcomp8 = '  Blue Pays            2X ';
	$rllvrcomp9 = '                          ';
	$rllvrcomp10 = '  Black Pays           2X ';
	$rllvrcomp11 = '                          ';
	$rllvrcomp12 = '  Double Thirds Pay  1.5X ';
	$rllvrcomp13 = '                          ';
	$rllvrcomp14 = '  Triple Fourths Pay 1.3X ';
	$rllvrcomp15 = '                          ';
	$rllvrcomp16 = '  Groups Pay           4X ';
	$rllvrcomp17 = '                          ';
	$rllvrcomp18 = '  Lines Pay           12X ';
	$rllvrcomp19 = '                          ';
	$rllvrcomp20 = ' Zeroes Pay          18X ';
	}
}

sub rllvrbetcomp {                               
	$rllvrcomp1 = '                         ';
	$rllvrcomp2 = '                          ';
	$rllvrcomp3 = '   Enter Your Bet:        ';
	$rllvrcomp4 = '                          ';
	$rllvrcomp5 = '                          ';
	$rllvrcomp6 = '                          ';
	$rllvrcomp7 = '                          ';
	$rllvrcomp8 = '                          ';
	$rllvrcomp9 = '                          ';
	$rllvrcomp10 = '                          ';
	$rllvrcomp11 = '                          ';
	$rllvrcomp12 = '                          ';
	$rllvrcomp13 = '                          ';
	$rllvrcomp14 = '                          ';
	$rllvrcomp15 = '                          ';
	$rllvrcomp16 = '                          ';
	$rllvrcomp17 = '                          ';
	$rllvrcomp18 = '                          ';
	$rllvrcomp19 = '                          ';
	$rllvrcomp20 = '                         ';
}

sub rllvrnbrcomp {
	$rllvrcomp1 = '  Choose Numbers:        ';                               
	$rllvrcomp2 = '*Enter A Number To Play # ';
	$rllvrcomp3 = '*Enter C1, C2, or C3 To   ';
	$rllvrcomp4 = '  Play Column 1, 2, or 3  ';
	$rllvrcomp5 = '*Enter T1, T2, or T3 To   ';
	$rllvrcomp6 = '  Play 2/3 Of The Wheel   ';
	$rllvrcomp7 = '*Enter F1..F4 To Play 3/4 ';
	$rllvrcomp8 = '*Enter EVEN To Play Even  ';
	$rllvrcomp9 = '*Enter ODD To Play Odd    ';
	if ($rllvrsetup == 0) {
		if ($rllvrfuturecarlo == 1) {
		$rllvrcomp10 = '*Enter MAGENTA To Play Mag';
		$rllvrcomp11 = '*Enter BLUE To Play Blue  ';
		} else {
		$rllvrcomp10 = '*Enter RED To Play Red    ';
		$rllvrcomp11 = '*Enter BLACK To Play Black';
		}
	} else {
	$rllvrcomp10 = '*Enter BLUE To Play Blue  ';
	$rllvrcomp11 = '*Enter BLACK To Play Black';
	}
	$rllvrcomp12 = '*Enter LOWER18 To Play Top';
	$rllvrcomp13 = '*Enter UPPER18 To Play Bot';
	$rllvrcomp14 = '*Enter G1, G2, G3, or G4  ';
	$rllvrcomp15 = '  To Play Group 1,2,3,or 4';
	$rllvrcomp16 = '*Enter L1,L2...L12 To Play';
	$rllvrcomp17 = '  Lines 1, 2 ... 12       ';
	if ($rllvrsetup == 0) {
	$rllvrcomp18 = '*Enter P2 To Play Powers  ';
	$rllvrcomp19 = '  Of Two                  ';
	$rllvrcomp20 = '*Enter Z To Play Zeroes  ';
	} else {
	$rllvrcomp18 = '*Enter Z To Play Zeroes   ';
	$rllvrcomp19 = '                          ';
	$rllvrcomp20 = '                         ';
	}	
}

sub rllvrtotal {
	sep;
	if ($money > 9999999999) {
	print colored(sprintf("%.4e", $money),"$rllvrcolor13 on_$rllvrcolor14");
	} elsif ($money >= 1000000000) {
	print colored("$money","$rllvrcolor13 on_$rllvrcolor14");
	} elsif ($money >= 100000000) {
	print colored(" $money","$rllvrcolor13 on_$rllvrcolor14");
	} elsif ($money >= 10000000) {
	print colored("  $money","$rllvrcolor13 on_$rllvrcolor14");
	} elsif ($money >= 1000000) {
	print colored("   $money","$rllvrcolor13 on_$rllvrcolor14");
	} elsif ($money >= 100000) {
	print colored("    $money","$rllvrcolor13 on_$rllvrcolor14");
	} elsif ($money >= 10000) {
	print colored("     $money","$rllvrcolor13 on_$rllvrcolor14");
	} elsif ($money >= 1000) {
	print colored("      $money","$rllvrcolor13 on_$rllvrcolor14");
	} elsif ($money >= 100) {
	print colored("       $money","$rllvrcolor13 on_$rllvrcolor14");
	} elsif ($money >= 10) {
	print colored("        $money","$rllvrcolor13 on_$rllvrcolor14");
	} elsif ($money >= 1) {
	print colored("         $money","$rllvrcolor13 on_$rllvrcolor14");
	} else {
	print colored("         $money","$rllvrcolor13 on_$rllvrcolor14");
	}
	sep; 
}

sub rllvrwinnings {
	sep; 
	if ($rllvrmoney > 9999999999) {
	print colored(sprintf("%.4e", $rllvrmoney),"$rllvrcolor13 on_$rllvrcolor14");
	} elsif ($rllvrmoney >= 1000000000) {
	print colored("$rllvrmoney","$rllvrcolor13 on_$rllvrcolor14");
	} elsif ($rllvrmoney >= 100000000) {
	print colored(" $rllvrmoney","$rllvrcolor13 on_$rllvrcolor14");
	} elsif ($rllvrmoney >= 10000000) {
	print colored("  $rllvrmoney","$rllvrcolor13 on_$rllvrcolor14");
	} elsif ($rllvrmoney >= 1000000) {
	print colored("   $rllvrmoney","$rllvrcolor13 on_$rllvrcolor14");
	} elsif ($rllvrmoney >= 100000) {
	print colored("    $rllvrmoney","$rllvrcolor13 on_$rllvrcolor14");
	} elsif ($rllvrmoney >= 10000) {
	print colored("     $rllvrmoney","$rllvrcolor13 on_$rllvrcolor14");
	} elsif ($rllvrmoney >= 1000) {
	print colored("      $rllvrmoney","$rllvrcolor13 on_$rllvrcolor14");
	} elsif ($rllvrmoney >= 100) {
	print colored("       $rllvrmoney","$rllvrcolor13 on_$rllvrcolor14");
	} elsif ($rllvrmoney >= 10) {
	print colored("        $rllvrmoney","$rllvrcolor13 on_$rllvrcolor14");
	} elsif ($rllvrmoney >= 1) {
	print colored("         $rllvrmoney","$rllvrcolor13 on_$rllvrcolor14");
	} else {
	print colored("         $rllvrmoney","$rllvrcolor13 on_$rllvrcolor14");
	}
	sep; 
}

sub rllvrbet {
	sep; 
	if ($rllvrbet > 9999999999) {
	print colored(sprintf("%.4e", $rllvrbet),"$rllvrcolor13 on_$rllvrcolor14");
	} elsif ($rllvrbet >= 1000000000) {
	print colored("$rllvrbet","$rllvrcolor13 on_$rllvrcolor14");
	} elsif ($rllvrbet >= 100000000) {
	print colored(" $rllvrbet","$rllvrcolor13 on_$rllvrcolor14");
	} elsif ($rllvrbet >= 10000000) {
	print colored("  $rllvrbet","$rllvrcolor13 on_$rllvrcolor14");
	} elsif ($rllvrbet >= 1000000) {
	print colored("   $rllvrbet","$rllvrcolor13 on_$rllvrcolor14");
	} elsif ($rllvrbet >= 100000) {
	print colored("    $rllvrbet","$rllvrcolor13 on_$rllvrcolor14");
	} elsif ($rllvrbet >= 10000) {
	print colored("     $rllvrbet","$rllvrcolor13 on_$rllvrcolor14");
	} elsif ($rllvrbet >= 1000) {
	print colored("      $rllvrbet","$rllvrcolor13 on_$rllvrcolor14");
	} elsif ($rllvrbet >= 100) {
	print colored("       $rllvrbet","$rllvrcolor13 on_$rllvrcolor14");
	} elsif ($rllvrbet >= 10) {
	print colored("        $rllvrbet","$rllvrcolor13 on_$rllvrcolor14");
	} elsif ($rllvrbet >= 1) {
	print colored("         $rllvrbet","$rllvrcolor13 on_$rllvrcolor14");
	} else {
	print colored("         $rllvrbet","$rllvrcolor13 on_$rllvrcolor14");
	}
	sep; 
}

sub rllvrspace1 {
	print colored('      ',"$rllvrcolor8 on_$rllvrcolor7");
}

sub rllvrb0000 {
	print colored('\\-----------------/',"$rllvrcolor8 on_$rllvrcolor7");
}

sub rllvrb000 {
	print colored('/-----------------\\',"$rllvrcolor8 on_$rllvrcolor7");
}

sub rllvrb00 {
	if ($rllvrsetup == 1) {
		#Roulette De Americana
		rllvrslot5();
		if ($rllvrb0p == 1) {
			print colored('    0   ',"$rllvrcolor18 on_$red");	
		} else {
			print colored('    0   ',"$boldred on_$rllvrcolor17");
		}
		rllvrslot5();
		if ($rllvrb00p == 1) {
			print colored('  0 0   ',"$rllvrcolor18 on_$red");	
		} else {
			print colored('  0 0   ',"$boldred on_$rllvrcolor17");
		}
		rllvrslot5();
	} else {
		#Monte Carlo Roulette
		rllvrslot5();
		if ($rllvrb0p == 1) {
			print colored('    0   ',"$rllvrcolor18 on_$rllvrcolor19");	
		} else {
			print colored('    0   ',"$rllvrcolor16 on_$rllvrcolor17");
		}
		rllvrslot5();
		if ($rllvrb00p == 1) {
			print colored('  0 0   ',"$rllvrcolor18 on_$rllvrcolor19");	
		} else {
			print colored('  0 0   ',"$rllvrcolor16 on_$rllvrcolor17");
		}
		rllvrslot5();
	}
}

sub rllvrb00000 {
	rllvrslot5();
	if ($rllvrbRp == 1) {
		print colored("$rllvrredvar","$rllvrcolor18 on_$rllvrcolor19");	
	} else {
		print colored("$rllvrredvar","$rllvrcolor16 on_$rllvrcolor17");
	}
	rllvrslot5();
	if ($rllvrbBp == 1) {
		print colored("$rllvrblkvar","$rllvrcolor18 on_$rllvrcolor19");	
	} else {
		print colored("$rllvrblkvar","$rllvrcolor16 on_$rllvrcolor17");
	}
	rllvrslot5();
}

sub rllvrb0 {
	print colored('|-----------------|',"$rllvrcolor8 on_$rllvrcolor7");
}

sub rllvrb1 {
	rllvrslot5();
	if ($rllvrb1p == 1) {
		print colored('  1  ',"$rllvrcolor18 on_$rllvrcolor19");	
	} else {
		print colored('  1  ',"$rllvrcolor16 on_$rllvrcolor17");
	}
	rllvrslot5();
	if ($rllvrb2p == 1) {
		print colored('  2  ',"$rllvrcolor18 on_$rllvrcolor19");	
	} else {
		print colored('  2  ',"$rllvrcolor16 on_$rllvrcolor17");
	}
	rllvrslot5();
	if ($rllvrb3p == 1) {
		print colored('  3  ',"$rllvrcolor18 on_$rllvrcolor19");	
	} else {
		print colored('  3  ',"$rllvrcolor16 on_$rllvrcolor17");
	}
	rllvrslot5();	
}

sub rllvrb2 {
	rllvrslot5();
	if ($rllvrb4p == 1) {
		print colored('  4  ',"$rllvrcolor18 on_$rllvrcolor19");	
	} else {
		print colored('  4  ',"$rllvrcolor16 on_$rllvrcolor17");
	}
	rllvrslot5();
	if ($rllvrb5p == 1) {
		print colored('  5  ',"$rllvrcolor18 on_$rllvrcolor19");	
	} else {
		print colored('  5  ',"$rllvrcolor16 on_$rllvrcolor17");
	}
	rllvrslot5();
	if ($rllvrb6p == 1) {
		print colored('  6  ',"$rllvrcolor18 on_$rllvrcolor19");	
	} else {
		print colored('  6  ',"$rllvrcolor16 on_$rllvrcolor17");
	}
	rllvrslot5();	
}

sub rllvrb3 {
	rllvrslot5();
	if ($rllvrb7p == 1) {
		print colored('  7  ',"$rllvrcolor18 on_$rllvrcolor19");	
	} else {
		print colored('  7  ',"$rllvrcolor16 on_$rllvrcolor17");
	}
	rllvrslot5();
	if ($rllvrb8p == 1) {
		print colored('  8  ',"$rllvrcolor18 on_$rllvrcolor19");	
	} else {
		print colored('  8  ',"$rllvrcolor16 on_$rllvrcolor17");
	}
	rllvrslot5();
	if ($rllvrb9p == 1) {
		print colored('  9  ',"$rllvrcolor18 on_$rllvrcolor19");	
	} else {
		print colored('  9  ',"$rllvrcolor16 on_$rllvrcolor17");
	}
	rllvrslot5();	
}

sub rllvrb4 {
	rllvrslot5();
	if ($rllvrb10p == 1) {
		print colored(' 1 0 ',"$rllvrcolor18 on_$rllvrcolor19");	
	} else {
		print colored(' 1 0 ',"$rllvrcolor16 on_$rllvrcolor17");
	}
	rllvrslot5();
	if ($rllvrb11p == 1) {
		print colored(' 1 1 ',"$rllvrcolor18 on_$rllvrcolor19");	
	} else {
		print colored(' 1 1 ',"$rllvrcolor16 on_$rllvrcolor17");
	}
	rllvrslot5();
	if ($rllvrb12p == 1) {
		print colored(' 1 2 ',"$rllvrcolor18 on_$rllvrcolor19");	
	} else {
		print colored(' 1 2 ',"$rllvrcolor16 on_$rllvrcolor17");
	}
	rllvrslot5();	
}

sub rllvrb5 {
	rllvrslot5();
	if ($rllvrb13p == 1) {
		print colored(' 1 3 ',"$rllvrcolor18 on_$rllvrcolor19");	
	} else {
		print colored(' 1 3 ',"$rllvrcolor16 on_$rllvrcolor17");
	}
	rllvrslot5();
	if ($rllvrb14p == 1) {
		print colored(' 1 4 ',"$rllvrcolor18 on_$rllvrcolor19");	
	} else {
		print colored(' 1 4 ',"$rllvrcolor16 on_$rllvrcolor17");
	}
	rllvrslot5();
	if ($rllvrb15p == 1) {
		print colored(' 1 5 ',"$rllvrcolor18 on_$rllvrcolor19");	
	} else {
		print colored(' 1 5 ',"$rllvrcolor16 on_$rllvrcolor17");
	}
	rllvrslot5();	
}

sub rllvrb6 {
	rllvrslot5();
	if ($rllvrb16p == 1) {
		print colored(' 1 6 ',"$rllvrcolor18 on_$rllvrcolor19");	
	} else {
		print colored(' 1 6 ',"$rllvrcolor16 on_$rllvrcolor17");
	}
	rllvrslot5();
	if ($rllvrb17p == 1) {
		print colored(' 1 7 ',"$rllvrcolor18 on_$rllvrcolor19");	
	} else {
		print colored(' 1 7 ',"$rllvrcolor16 on_$rllvrcolor17");
	}
	rllvrslot5();
	if ($rllvrb18p == 1) {
		print colored(' 1 8 ',"$rllvrcolor18 on_$rllvrcolor19");	
	} else {
		print colored(' 1 8 ',"$rllvrcolor16 on_$rllvrcolor17");
	}
	rllvrslot5();	
}

sub rllvrb7 {
	rllvrslot5();
	if ($rllvrb19p == 1) {
		print colored(' 1 9 ',"$rllvrcolor18 on_$rllvrcolor19");	
	} else {
		print colored(' 1 9 ',"$rllvrcolor16 on_$rllvrcolor17");
	}
	rllvrslot5();
	if ($rllvrb20p == 1) {
		print colored(' 2 0 ',"$rllvrcolor18 on_$rllvrcolor19");	
	} else {
		print colored(' 2 0 ',"$rllvrcolor16 on_$rllvrcolor17");
	}
	rllvrslot5();
	if ($rllvrb21p == 1) {
		print colored(' 2 1 ',"$rllvrcolor18 on_$rllvrcolor19");	
	} else {
		print colored(' 2 1 ',"$rllvrcolor16 on_$rllvrcolor17");
	}
	rllvrslot5();	
}

sub rllvrb8 {
	rllvrslot5();
	if ($rllvrb22p == 1) {
		print colored(' 2 2 ',"$rllvrcolor18 on_$rllvrcolor19");	
	} else {
		print colored(' 2 2 ',"$rllvrcolor16 on_$rllvrcolor17");
	}
	rllvrslot5();
	if ($rllvrb23p == 1) {
		print colored(' 2 3 ',"$rllvrcolor18 on_$rllvrcolor19");	
	} else {
		print colored(' 2 3 ',"$rllvrcolor16 on_$rllvrcolor17");
	}
	rllvrslot5();
	if ($rllvrb24p == 1) {
		print colored(' 2 4 ',"$rllvrcolor18 on_$rllvrcolor19");	
	} else {
		print colored(' 2 4 ',"$rllvrcolor16 on_$rllvrcolor17");
	}
	rllvrslot5();	
}

sub rllvrb9 {
	rllvrslot5();
	if ($rllvrb25p == 1) {
		print colored(' 2 5 ',"$rllvrcolor18 on_$rllvrcolor19");	
	} else {
		print colored(' 2 5 ',"$rllvrcolor16 on_$rllvrcolor17");
	}
	rllvrslot5();
	if ($rllvrb26p == 1) {
		print colored(' 2 6 ',"$rllvrcolor18 on_$rllvrcolor19");	
	} else {
		print colored(' 2 6 ',"$rllvrcolor16 on_$rllvrcolor17");
	}
	rllvrslot5();
	if ($rllvrb27p == 1) {
		print colored(' 2 7 ',"$rllvrcolor18 on_$rllvrcolor19");	
	} else {
		print colored(' 2 7 ',"$rllvrcolor16 on_$rllvrcolor17");
	}
	rllvrslot5();	
}

sub rllvrb10 {
	rllvrslot5();
	if ($rllvrb28p == 1) {
		print colored(' 2 8 ',"$rllvrcolor18 on_$rllvrcolor19");	
	} else {
		print colored(' 2 8 ',"$rllvrcolor16 on_$rllvrcolor17");
	}
	rllvrslot5();
	if ($rllvrb29p == 1) {
		print colored(' 2 9 ',"$rllvrcolor18 on_$rllvrcolor19");	
	} else {
		print colored(' 2 9 ',"$rllvrcolor16 on_$rllvrcolor17");
	}
	rllvrslot5();
	if ($rllvrb30p == 1) {
		print colored(' 3 0 ',"$rllvrcolor18 on_$rllvrcolor19");	
	} else {
		print colored(' 3 0 ',"$rllvrcolor16 on_$rllvrcolor17");
	}
	rllvrslot5();	
}

sub rllvrb11 {
	rllvrslot5();
	if ($rllvrb31p == 1) {
		print colored(' 3 1 ',"$rllvrcolor18 on_$rllvrcolor19");	
	} else {
		print colored(' 3 1 ',"$rllvrcolor16 on_$rllvrcolor17");
	}
	rllvrslot5();
	if ($rllvrb32p == 1) {
		print colored(' 3 2 ',"$rllvrcolor18 on_$rllvrcolor19");	
	} else {
		print colored(' 3 2 ',"$rllvrcolor16 on_$rllvrcolor17");
	}
	rllvrslot5();
	if ($rllvrb33p == 1) {
		print colored(' 3 3 ',"$rllvrcolor18 on_$rllvrcolor19");	
	} else {
		print colored(' 3 3 ',"$rllvrcolor16 on_$rllvrcolor17");
	}
	rllvrslot5();	
}

sub rllvrb12 {
	rllvrslot5();
	if ($rllvrb34p == 1) {
		print colored(' 3 4 ',"$rllvrcolor18 on_$rllvrcolor19");	
	} else {
		print colored(' 3 4 ',"$rllvrcolor16 on_$rllvrcolor17");
	}
	rllvrslot5();
	if ($rllvrb35p == 1) {
		print colored(' 3 5 ',"$rllvrcolor18 on_$rllvrcolor19");	
	} else {
		print colored(' 3 5 ',"$rllvrcolor16 on_$rllvrcolor17");
	}
	rllvrslot5();
	if ($rllvrb36p == 1) {
		print colored(' 3 6 ',"$rllvrcolor18 on_$rllvrcolor19");	
	} else {
		print colored(' 3 6 ',"$rllvrcolor16 on_$rllvrcolor17");
	}
	rllvrslot5();	
}


################################################################################################################################
## GENRE: Dice
## NAME: Sic Bo Tai Sai
## AUTHOR: MikeeUSA

sub sbtresetnum {
	$sbtRtotal4 = 0;
	$sbtRtotal5 = 0;
	$sbtRtotal6 = 0;
	$sbtRtotal7 = 0;
	$sbtRtotal8 = 0;
	$sbtRtotal9 = 0;
	$sbtRtotal10 = 0;
	$sbtRtotal11 = 0;
	$sbtRtotal12 = 0;
	$sbtRtotal13 = 0;
	$sbtRtotal14 = 0;
	$sbtRtotal15 = 0;
	$sbtRtotal16 = 0;
	$sbtRtotal17 = 0;
	$sbtRtotalSM = 0;
	$sbtRtotalBG = 0;
	$sbtRtotalANYTRI = 0;
	$sbtRtotalSPFTRI = 0;
	$sbtRtotalSPFDOB = 0;
	$sbtRtotalNUMBER = 0;
}

sub sbtmainspin1 {
	sbtreset();
	sbtcompvars1();
	sbtcolors();
	
	if ($animate == 1) {
		$sbtcolorD0 = $sbtcolorD2;
		
		sbtthrowdice();
		sbtmainprint();
		p7pause();
		newlines();
		
		sbtthrowdice();
		sbtmainprint();
		p7pause();
		newlines();
		
		sbtthrowdice();
		sbtmainprint();
		p7pause();
		newlines();
		
		sbtthrowdice();
		sbtmainprint();
		p7pause();
		newlines();
		
		sbtthrowdice();
		sbtmainprint();
		p7pause();
		newlines();
		
		sbtthrowdice();
		sbtmainprint();
		p7pause();
		newlines();
		
		sbtthrowdice();
		sbtmainprint();
		p7pause();
		newlines();
		
		sbtthrowdice();
		sbtmainprint();
		p7pause();
		newlines();
		
		sbtthrowdice();
		sbtmainprint();
		p7pause();
		newlines();
		
		sbtthrowdice();
		sbtmainprint();
		p7pause();
		newlines();
		
		sbtcolors();
	}

	sbtthrowdice();
	sbtaddmoney();
	sbtmainprint();	
	ptracker();
	sbtstdin1();	
}

sub sbtmainspin2 {
	sbtreset();
	sbtcompvars1();
	sbtcolors();
	sbtmainprint();		
	sbtstdin1();
}

sub sbtmainspin3 {
	sbtreset();
	sbtcompvars2();
	sbtcolors();
	sbtmainprint();	
	$sbtstart2 = <STDIN>;
	chomp($sbtstart2);
	sbtresetnum();	
	if (($sbtstart2 eq 't4') or ($sbtstart2 eq 'T4')) {
		$sbtstart2 = 'T4';
		$sbtRtotal4 = 1;
	} elsif (($sbtstart2 eq 't5') or ($sbtstart2 eq 'T5')) {
		$sbtstart2 = 'T5';
		$sbtRtotal5 = 1;
	} elsif (($sbtstart2 eq 't6') or ($sbtstart2 eq 'T6')) {
		$sbtstart2 = 'T6';
		$sbtRtotal6 = 1;
	} elsif (($sbtstart2 eq 't7') or ($sbtstart2 eq 'T7')) {
		$sbtstart2 = 'T7';
		$sbtRtotal7 = 1;
	} elsif (($sbtstart2 eq 't8') or ($sbtstart2 eq 'T8')) {
		$sbtstart2 = 'T8';
		$sbtRtotal8 = 1;
	} elsif (($sbtstart2 eq 't9') or ($sbtstart2 eq 'T9')) {
		$sbtstart2 = 'T9';
		$sbtRtotal9 = 1;
	} elsif (($sbtstart2 eq 't10') or ($sbtstart2 eq 'T10')) {
		$sbtstart2 = 'T10';
		$sbtRtotal10 = 1;
	} elsif (($sbtstart2 eq 't11') or ($sbtstart2 eq 'T11')) {
		$sbtstart2 = 'T11';
		$sbtRtotal11 = 1;
	} elsif (($sbtstart2 eq 't12') or ($sbtstart2 eq 'T12')) {
		$sbtstart2 = 'T12';
		$sbtRtotal12 = 1;
	} elsif (($sbtstart2 eq 't13') or ($sbtstart2 eq 'T13')) {
		$sbtstart2 = 'T13';
		$sbtRtotal13 = 1;
	} elsif (($sbtstart2 eq 't14') or ($sbtstart2 eq 'T14')) {
		$sbtstart2 = 'T14';
		$sbtRtotal14 = 1;
	} elsif (($sbtstart2 eq 't15') or ($sbtstart2 eq 'T15')) {
		$sbtstart2 = 'T15';
		$sbtRtotal15 = 1;
	} elsif (($sbtstart2 eq 't16') or ($sbtstart2 eq 'T16')) {
		$sbtstart2 = 'T16';
		$sbtRtotal16 = 1;
	} elsif (($sbtstart2 eq 't17') or ($sbtstart2 eq 'T17')) {
		$sbtstart2 = 'T17';
		$sbtRtotal17 = 1;
	} elsif (($sbtstart2 eq 'anytri') or ($sbtstart2 eq 'ANYTRI')) {
		$sbtstart2 = 'ANYTRI';
		$sbtRtotalANYTRI = 1;
	} elsif (($sbtstart2 eq 'small') or ($sbtstart2 eq 'SMALL')) {
		$sbtstart2 = 'SMALL';
		$sbtRtotalSM = 1;		
	} elsif (($sbtstart2 eq 'big') or ($sbtstart2 eq 'BIG')) {
		$sbtstart2 = 'BIG';
		$sbtRtotalBG = 1;
	} elsif (($sbtstart2 eq 'st1') or ($sbtstart2 eq 'ST1')) {
		$sbtstart2 = 'ST1';
		$sbtRtotalSPFTRI = 1;
	} elsif (($sbtstart2 eq 'st2') or ($sbtstart2 eq 'ST2')) {
		$sbtstart2 = 'ST2';
		$sbtRtotalSPFTRI = 2;
	} elsif (($sbtstart2 eq 'st3') or ($sbtstart2 eq 'ST3')) {
		$sbtstart2 = 'ST3';
		$sbtRtotalSPFTRI = 3;
	} elsif (($sbtstart2 eq 'st4') or ($sbtstart2 eq 'ST4')) {
		$sbtstart2 = 'ST4';
		$sbtRtotalSPFTRI = 4;
	} elsif (($sbtstart2 eq 'st5') or ($sbtstart2 eq 'ST5')) {
		$sbtstart2 = 'ST5';
		$sbtRtotalSPFTRI = 5;
	} elsif (($sbtstart2 eq 'st6') or ($sbtstart2 eq 'ST6')) {
		$sbtstart2 = 'ST6';
		$sbtRtotalSPFTRI = 6;
	} elsif (($sbtstart2 eq 'sd1') or ($sbtstart2 eq 'SD1')) {
		$sbtstart2 = 'SD1';		
		$sbtRtotalSPFDOB = 1;
	} elsif (($sbtstart2 eq 'sd2') or ($sbtstart2 eq 'SD2')) {
		$sbtstart2 = 'SD2';		
		$sbtRtotalSPFDOB = 2;	
	} elsif (($sbtstart2 eq 'sd3') or ($sbtstart2 eq 'SD3')) {
		$sbtstart2 = 'SD3';		
		$sbtRtotalSPFDOB = 3;
	} elsif (($sbtstart2 eq 'sd4') or ($sbtstart2 eq 'SD4')) {
		$sbtstart2 = 'SD4';		
		$sbtRtotalSPFDOB = 4;	
	} elsif (($sbtstart2 eq 'sd5') or ($sbtstart2 eq 'SD5')) {
		$sbtstart2 = 'SD5';		
		$sbtRtotalSPFDOB = 5;
	} elsif (($sbtstart2 eq 'sd6') or ($sbtstart2 eq 'SD6')) {
		$sbtstart2 = 'SD6';		
		$sbtRtotalSPFDOB = 6;
	} elsif (($sbtstart2 eq 'n1') or ($sbtstart2 eq 'N1')) {
		$sbtstart2 = 'N1';		
		$sbtRtotalNUMBER = 1;
	} elsif (($sbtstart2 eq 'n2') or ($sbtstart2 eq 'N2')) {
		$sbtstart2 = 'N2';		
		$sbtRtotalNUMBER = 2;	
	} elsif (($sbtstart2 eq 'n3') or ($sbtstart2 eq 'N3')) {
		$sbtstart2 = 'N3';		
		$sbtRtotalNUMBER = 3;	
	} elsif (($sbtstart2 eq 'n4') or ($sbtstart2 eq 'N4')) {
		$sbtstart2 = 'N4';		
		$sbtRtotalNUMBER = 4;	
	} elsif (($sbtstart2 eq 'n5') or ($sbtstart2 eq 'N5')) {
		$sbtstart2 = 'N5';		
		$sbtRtotalNUMBER = 5;	
	} elsif (($sbtstart2 eq 'n6') or ($sbtstart2 eq 'N6')) {
		$sbtstart2 = 'N6';		
		$sbtRtotalNUMBER = 6;						
	} else {
		$sbtstart2 = ' ';
	} 	
	newlines();
	sbtmainspin2();
}

sub sbtaddmoney {
	$sbtdrand4 = ("$sbtdrand1"."$sbtdrand2"."$sbtdrand3");
	$sbtadded = ($sbtdrand1 + $sbtdrand2 + $sbtdrand3);
	if (($sbtadded eq 4) && ($sbtstart2 eq 'T4')) {
		$sbtaddmoney = $sbtbet * 61;
		$sbtstwin = $sbtstwin + 1;
	} elsif (($sbtadded eq 5) && ($sbtstart2 eq 'T5')) {
		$sbtaddmoney = $sbtbet * 31;
		$sbtstwin = $sbtstwin + 1;
	} elsif (($sbtadded eq 6) && ($sbtstart2 eq 'T6')) {
		$sbtaddmoney = $sbtbet * 19;
		$sbtstwin = $sbtstwin + 1;
	} elsif (($sbtadded eq 7) && ($sbtstart2 eq 'T7')) {
		$sbtaddmoney = $sbtbet * 13;
		$sbtstwin = $sbtstwin + 1;
	} elsif (($sbtadded eq 8) && ($sbtstart2 eq 'T8')) {
		$sbtaddmoney = $sbtbet * 9;
		$sbtstwin = $sbtstwin + 1;
	} elsif (($sbtadded eq 9) && ($sbtstart2 eq 'T9')) {
		$sbtaddmoney = $sbtbet * 8;
		$sbtstwin = $sbtstwin + 1;
	} elsif (($sbtadded eq 10) && ($sbtstart2 eq 'T10')) {
		$sbtaddmoney = $sbtbet * 7;
		$sbtstwin = $sbtstwin + 1;
	} elsif (($sbtadded eq 11) && ($sbtstart2 eq 'T11')) {
		$sbtaddmoney = $sbtbet * 7;
		$sbtstwin = $sbtstwin + 1;	
	} elsif (($sbtadded eq 12) && ($sbtstart2 eq 'T12')) {
		$sbtaddmoney = $sbtbet * 8;
		$sbtstwin = $sbtstwin + 1;	
	} elsif (($sbtadded eq 13) && ($sbtstart2 eq 'T13')) {
		$sbtaddmoney = $sbtbet * 9;
		$sbtstwin = $sbtstwin + 1;	
	} elsif (($sbtadded eq 14) && ($sbtstart2 eq 'T14')) {
		$sbtaddmoney = $sbtbet * 13;
		$sbtstwin = $sbtstwin + 1;	
	} elsif (($sbtadded eq 15) && ($sbtstart2 eq 'T15')) {
		$sbtaddmoney = $sbtbet * 19;
		$sbtstwin = $sbtstwin + 1;	
	} elsif (($sbtadded eq 16) && ($sbtstart2 eq 'T16')) {
		$sbtaddmoney = $sbtbet * 31;
		$sbtstwin = $sbtstwin + 1;	
	} elsif (($sbtadded eq 17) && ($sbtstart2 eq 'T17')) {
		$sbtaddmoney = $sbtbet * 31;
		$sbtstwin = $sbtstwin + 1;
	} elsif (($sbtadded > 10) && ($sbtstart2 eq 'BIG')) {
		if (($sbtdrand4 eq 111) or 
		($sbtdrand4 eq 222) or  
		($sbtdrand4 eq 333) or  
		($sbtdrand4 eq 444) or   
		($sbtdrand4 eq 555) or   
		($sbtdrand4 eq 666)) {
			$sbtaddmoney = 0;
			$sbtstlose = $sbtstlose + 1;
		} else {
			$sbtaddmoney = $sbtbet * 2;
			$sbtstwin = $sbtstwin + 1;
		}
	} elsif (($sbtadded < 11) && ($sbtstart2 eq 'SMALL')) {
		if (($sbtdrand4 eq 111) or 
		($sbtdrand4 eq 222) or  
		($sbtdrand4 eq 333) or  
		($sbtdrand4 eq 444) or   
		($sbtdrand4 eq 555) or   
		($sbtdrand4 eq 666)) {
			$sbtaddmoney = 0;
			$sbtstlose = $sbtstlose + 1;
		} else {
			$sbtaddmoney = $sbtbet * 2;
			$sbtstwin = $sbtstwin + 1;
		}			
	} elsif ((($sbtstart2 eq 'ANYTRI') && ($sbtdrand4 eq 111)) or
	(($sbtstart2 eq 'ANYTRI') && ($sbtdrand4 eq 222)) or
	(($sbtstart2 eq 'ANYTRI') && ($sbtdrand4 eq 333)) or
	(($sbtstart2 eq 'ANYTRI') && ($sbtdrand4 eq 444)) or
	(($sbtstart2 eq 'ANYTRI') && ($sbtdrand4 eq 555)) or
	(($sbtstart2 eq 'ANYTRI') && ($sbtdrand4 eq 666))) {
		$sbtaddmoney = $sbtbet * 31;
		$sbtstwin = $sbtstwin + 1;
	} elsif (($sbtstart2 eq 'ST1') && ($sbtdrand4 eq 111)) {
		$sbtaddmoney = $sbtbet * 180;
		$sbtstwin = $sbtstwin + 1;
	} elsif (($sbtstart2 eq 'ST2') && ($sbtdrand4 eq 222)) {
		$sbtaddmoney = $sbtbet * 180;
		$sbtstwin = $sbtstwin + 1;
	} elsif (($sbtstart2 eq 'ST3') && ($sbtdrand4 eq 333)) {
		$sbtaddmoney = $sbtbet * 180;
		$sbtstwin = $sbtstwin + 1;
	} elsif (($sbtstart2 eq 'ST4') && ($sbtdrand4 eq 444)) {
		$sbtaddmoney = $sbtbet * 180;
		$sbtstwin = $sbtstwin + 1;
	} elsif (($sbtstart2 eq 'ST5') && ($sbtdrand4 eq 555)) {
		$sbtaddmoney = $sbtbet * 180;
		$sbtstwin = $sbtstwin + 1;
	} elsif (($sbtstart2 eq 'ST6') && ($sbtdrand4 eq 666)) {
		$sbtaddmoney = $sbtbet * 180;
		$sbtstwin = $sbtstwin + 1;
	} elsif ($sbtstart2 eq 'SD1') {
		if ((($sbtdrand1 eq 1) && ($sbtdrand2 eq 1)) or
		(($sbtdrand2 eq 1) && ($sbtdrand3 eq 1)) or
		(($sbtdrand1 eq 1) && ($sbtdrand3 eq 1))) {
			$sbtaddmoney = $sbtbet * 11;
			$sbtstwin = $sbtstwin + 1;
		} else {
			$sbtaddmoney = 0;
			$sbtstlose = $sbtstlose + 1;		
		}
	} elsif ($sbtstart2 eq 'SD2') {
		if ((($sbtdrand1 eq 2) && ($sbtdrand2 eq 2)) or
		(($sbtdrand2 eq 2) && ($sbtdrand3 eq 2)) or
		(($sbtdrand1 eq 2) && ($sbtdrand3 eq 2))) {
			$sbtaddmoney = $sbtbet * 11;
			$sbtstwin = $sbtstwin + 1;
		} else {
			$sbtaddmoney = 0;
			$sbtstlose = $sbtstlose + 1;		
		}
	} elsif ($sbtstart2 eq 'SD3') {
		if ((($sbtdrand1 eq 3) && ($sbtdrand2 eq 3)) or
		(($sbtdrand2 eq 3) && ($sbtdrand3 eq 3)) or
		(($sbtdrand1 eq 3) && ($sbtdrand3 eq 3))) {
			$sbtaddmoney = $sbtbet * 11;
			$sbtstwin = $sbtstwin + 1;
		} else {
			$sbtaddmoney = 0;
			$sbtstlose = $sbtstlose + 1;		
		}
	} elsif ($sbtstart2 eq 'SD4') {
		if ((($sbtdrand1 eq 4) && ($sbtdrand2 eq 4)) or
		(($sbtdrand2 eq 4) && ($sbtdrand3 eq 4)) or
		(($sbtdrand1 eq 4) && ($sbtdrand3 eq 4))) {
			$sbtaddmoney = $sbtbet * 11;
			$sbtstwin = $sbtstwin + 1;
		} else {
			$sbtaddmoney = 0;
			$sbtstlose = $sbtstlose + 1;		
		}
	} elsif ($sbtstart2 eq 'SD5') {
		if ((($sbtdrand1 eq 5) && ($sbtdrand2 eq 5)) or
		(($sbtdrand2 eq 5) && ($sbtdrand3 eq 5)) or
		(($sbtdrand1 eq 5) && ($sbtdrand3 eq 5))) {
			$sbtaddmoney = $sbtbet * 11;
			$sbtstwin = $sbtstwin + 1;
		} else {
			$sbtaddmoney = 0;
			$sbtstlose = $sbtstlose + 1;		
		}
	} elsif ($sbtstart2 eq 'SD6') {
		if ((($sbtdrand1 eq 6) && ($sbtdrand2 eq 6)) or
		(($sbtdrand2 eq 6) && ($sbtdrand3 eq 6)) or
		(($sbtdrand1 eq 6) && ($sbtdrand3 eq 6))) {
			$sbtaddmoney = $sbtbet * 11;
			$sbtstwin = $sbtstwin + 1;
		} else {
			$sbtaddmoney = 0;
			$sbtstlose = $sbtstlose + 1;		
		}
	} elsif ($sbtstart2 eq 'N1') {
		if ($sbtdrand4 eq 111) {
			$sbtaddmoney = $sbtbet * 11;
			$sbtstwin = $sbtstwin + 1;
		} elsif ((($sbtdrand1 eq 1) && ($sbtdrand2 eq 1)) or
		(($sbtdrand2 eq 1) && ($sbtdrand3 eq 1)) or
		(($sbtdrand1 eq 1) && ($sbtdrand3 eq 1))) {
			$sbtaddmoney = $sbtbet * 3;
			$sbtstwin = $sbtstwin + 1;
		} elsif (($sbtdrand1 eq 1) or ($sbtdrand2 eq 1) or ($sbtdrand3 eq 1)) {
			$sbtaddmoney = $sbtbet * 2;
			$sbtstwin = $sbtstwin + 1;			
		} else {
			$sbtaddmoney = 0;
			$sbtstlose = $sbtstlose + 1;		
		}
	} elsif ($sbtstart2 eq 'N2') {
		if ($sbtdrand4 eq 222) {
			$sbtaddmoney = $sbtbet * 11;
			$sbtstwin = $sbtstwin + 1;
		} elsif ((($sbtdrand1 eq 2) && ($sbtdrand2 eq 2)) or
		(($sbtdrand2 eq 2) && ($sbtdrand3 eq 2)) or
		(($sbtdrand1 eq 2) && ($sbtdrand3 eq 2))) {
			$sbtaddmoney = $sbtbet * 3;
			$sbtstwin = $sbtstwin + 1;
		} elsif (($sbtdrand1 eq 2) or ($sbtdrand2 eq 2) or ($sbtdrand3 eq 2)) {
			$sbtaddmoney = $sbtbet * 2;
			$sbtstwin = $sbtstwin + 1;			
		} else {
			$sbtaddmoney = 0;
			$sbtstlose = $sbtstlose + 1;		
		}	
	} elsif ($sbtstart2 eq 'N3') {
		if ($sbtdrand4 eq 333) {
			$sbtaddmoney = $sbtbet * 11;
			$sbtstwin = $sbtstwin + 1;
		} elsif ((($sbtdrand1 eq 3) && ($sbtdrand2 eq 3)) or
		(($sbtdrand2 eq 3) && ($sbtdrand3 eq 3)) or
		(($sbtdrand1 eq 3) && ($sbtdrand3 eq 3))) {
			$sbtaddmoney = $sbtbet * 3;
			$sbtstwin = $sbtstwin + 1;
		} elsif (($sbtdrand1 eq 3) or ($sbtdrand2 eq 3) or ($sbtdrand3 eq 3)) {
			$sbtaddmoney = $sbtbet * 2;
			$sbtstwin = $sbtstwin + 1;			
		} else {
			$sbtaddmoney = 0;
			$sbtstlose = $sbtstlose + 1;		
		}		
	} elsif ($sbtstart2 eq 'N4') {
		if ($sbtdrand4 eq 444) {
			$sbtaddmoney = $sbtbet * 11;
			$sbtstwin = $sbtstwin + 1;
		} elsif ((($sbtdrand1 eq 4) && ($sbtdrand2 eq 4)) or
		(($sbtdrand2 eq 4) && ($sbtdrand3 eq 4)) or
		(($sbtdrand1 eq 4) && ($sbtdrand3 eq 4))) {
			$sbtaddmoney = $sbtbet * 3;
			$sbtstwin = $sbtstwin + 1;
		} elsif (($sbtdrand1 eq 4) or ($sbtdrand2 eq 4) or ($sbtdrand3 eq 4)) {
			$sbtaddmoney = $sbtbet * 2;
			$sbtstwin = $sbtstwin + 1;			
		} else {
			$sbtaddmoney = 0;
			$sbtstlose = $sbtstlose + 1;		
		}		
	} elsif ($sbtstart2 eq 'N5') {
		if ($sbtdrand4 eq 555) {
			$sbtaddmoney = $sbtbet * 11;
			$sbtstwin = $sbtstwin + 1;
		} elsif ((($sbtdrand1 eq 5) && ($sbtdrand2 eq 5)) or
		(($sbtdrand2 eq 5) && ($sbtdrand3 eq 5)) or
		(($sbtdrand1 eq 5) && ($sbtdrand3 eq 5))) {
			$sbtaddmoney = $sbtbet * 3;
			$sbtstwin = $sbtstwin + 1;
		} elsif (($sbtdrand1 eq 5) or ($sbtdrand2 eq 5) or ($sbtdrand3 eq 5)) {
			$sbtaddmoney = $sbtbet * 2;
			$sbtstwin = $sbtstwin + 1;			
		} else {
			$sbtaddmoney = 0;
			$sbtstlose = $sbtstlose + 1;		
		}			
	} elsif ($sbtstart2 eq 'N6') {
		if ($sbtdrand4 eq 666) {
			$sbtaddmoney = $sbtbet * 11;
			$sbtstwin = $sbtstwin + 1;
		} elsif ((($sbtdrand1 eq 6) && ($sbtdrand2 eq 6)) or
		(($sbtdrand2 eq 6) && ($sbtdrand3 eq 6)) or
		(($sbtdrand1 eq 6) && ($sbtdrand3 eq 6))) {
			$sbtaddmoney = $sbtbet * 3;
			$sbtstwin = $sbtstwin + 1;
		} elsif (($sbtdrand1 eq 6) or ($sbtdrand2 eq 6) or ($sbtdrand3 eq 6)) {
			$sbtaddmoney = $sbtbet * 2;
			$sbtstwin = $sbtstwin + 1;			
		} else {
			$sbtaddmoney = 0;
			$sbtstlose = $sbtstlose + 1;		
		}							
	} else {
		$sbtaddmoney = 0;
		$sbtstlose = $sbtstlose + 1;
	}
	$sbtstmc = $sbtstmc + $sbtaddmoney;
	$sbtmoney = $sbtaddmoney;
	$money = $money + $sbtaddmoney;												
}

sub sbtreset {
	$sbtaddmoney = 0;
	$sbtmoney = 0; 
}

sub sbtmainspin4 {
	sbtreset();
	sbtcompvars3();
	sbtcolors();
	sbtmainprint();		
	$sbtstart3 = <STDIN>;
	chomp($sbtstart3);
	
	if ($sbtstart3 > $money) {
		$sbtbet = 0;
	} elsif ($sbtstart3 <= 0) {
		$sbtbet = 0;	 	
	} else {
		$sbtbet = sprintf("%.0f", $sbtstart3 )
	}	
	newlines();
	sbtmainspin2();
}

sub sbtcolors {
	$sbtcolorD0 = "$black";
	$sbtcolorD1 = "$bgcwhite";
	$sbtcolorD2 = "$boldblack";	
	$sbtcolor0 = "$boldyellow";
	$sbtcolor1 = "$bgcgreen"; #red $Table background
	$sbtcolor2 = "$yellow";
	$sbtcolor3 = "$boldwhite";
	$sbtcolor4 = "$green";
	$sbtcolor5 = "$bgcblack";
	$sbtcolor6 = "$white";
	$sbtcolor7 = "$bgcyellow";
	$sbtcolor8 = "$boldyellow"; #Total Deactivated For
	$sbtcolor9 = "$bgcblack";       #Total Deactivated Back
	$sbtcolor10 = "$red";        #Total Activated For
	$sbtcolor11 = "$bgcwhite";      #Total Activated Back
	$sbtcolor12 = "$boldred";
	$sbtcolor13 = "$boldblack";
	$sbtcolor14 = "$boldwhite";
	$sbtcolor15 = "$boldgreen";
	$sbtcolor16 = "$bgcgreen";	#Specific tri/double "LCD" back
	$sbtcolor17 = "$boldblack";
	$sbtcolor18 = "$bgcwhite";
	$sbtcolor19 = "$boldgreen";
	$sbtcolor20 = "$bgcblack";
	$sbtcolor21 = "$boldred";
	$sbtcolor22 = "$bgcred";	#N U M B E R   B E T  "LCD" back
}

sub sbtstdin1 {
	$sbtstart1 = <STDIN>;
	chomp($sbtstart1);
	if (($sbtstart1 eq 'P') or ($sbtstart1 eq 'p') or ($sbtstart1 eq 'a') or ($sbtstart1 eq 'A')) {
		if ($sbtstart2 eq ' ') {
			newlines();
			sbtmainspin2();
		} elsif ($sbtbet == 0) {
			newlines();
			sbtmainspin2();	
		} elsif ($money >= $sbtbet) {
			$money = $money - $sbtbet;
			$moneyexp = $moneyexp + $sbtbet;
			$sbtstmc2 = $sbtstmc2 + $sbtbet;
			$sbtstspins = $sbtstspins + 1;
			newlines();
			sbtmainspin1();
		} else {
			newlines();
			sbtmainspin2();
		}
	} elsif (($sbtstart1 eq 'N') or ($sbtstart1 eq 'n')) {
		newlines();
		sbtmainspin3();
	} elsif (($sbtstart1 eq 'B') or ($sbtstart1 eq 'b')) {
		newlines();
		sbtmainspin4();
	} elsif (($sbtstart1 eq 'C') or ($sbtstart1 eq 'c')) {
		return;
	} elsif (($sbtstart1 eq 'EXIT') or ($sbtstart1 eq 'exit') or ($sbtstart1 eq 'QUIT') or ($sbtstart1 eq 'quit')) {
		exitgame();	
	} else {
		newlines();
		sbtmainspin2();	
	}
}

sub sbtdbet {
	sep;
	if ($sbtbet > 9999999999) {
	print colored(sprintf("%.4e", $sbtbet),"$sbtcolor4 on_$sbtcolor5");
	} elsif ($sbtbet >= 1000000000) {
	print colored("$sbtbet","$sbtcolor4 on_$sbtcolor5");
	} elsif ($sbtbet >= 100000000) {
	print colored(" $sbtbet","$sbtcolor4 on_$sbtcolor5");
	} elsif ($sbtbet >= 10000000) {
	print colored("  $sbtbet","$sbtcolor4 on_$sbtcolor5");
	} elsif ($sbtbet >= 1000000) {
	print colored("   $sbtbet","$sbtcolor4 on_$sbtcolor5");
	} elsif ($sbtbet >= 100000) {
	print colored("    $sbtbet","$sbtcolor4 on_$sbtcolor5");
	} elsif ($sbtbet >= 10000) {
	print colored("     $sbtbet","$sbtcolor4 on_$sbtcolor5");
	} elsif ($sbtbet >= 1000) {
	print colored("      $sbtbet","$sbtcolor4 on_$sbtcolor5");
	} elsif ($sbtbet >= 100) {
	print colored("       $sbtbet","$sbtcolor4 on_$sbtcolor5");
	} elsif ($sbtbet >= 10) {
	print colored("        $sbtbet","$sbtcolor4 on_$sbtcolor5");
	} elsif ($sbtbet >= 1) {
	print colored("         $sbtbet","$sbtcolor4 on_$sbtcolor5");
	} else {
	print colored("         $sbtbet","$sbtcolor4 on_$sbtcolor5");
	}
	sep;
}

sub sbtdmoney {
	sep;
	if ($money > 9999999999) {
	print colored(sprintf("%.4e", $money),"$sbtcolor4 on_$sbtcolor5");
	} elsif ($money >= 1000000000) {
	print colored("$money","$sbtcolor4 on_$sbtcolor5");
	} elsif ($money >= 100000000) {
	print colored(" $money","$sbtcolor4 on_$sbtcolor5");
	} elsif ($money >= 10000000) {
	print colored("  $money","$sbtcolor4 on_$sbtcolor5");
	} elsif ($money >= 1000000) {
	print colored("   $money","$sbtcolor4 on_$sbtcolor5");
	} elsif ($money >= 100000) {
	print colored("    $money","$sbtcolor4 on_$sbtcolor5");
	} elsif ($money >= 10000) {
	print colored("     $money","$sbtcolor4 on_$sbtcolor5");
	} elsif ($money >= 1000) {
	print colored("      $money","$sbtcolor4 on_$sbtcolor5");
	} elsif ($money >= 100) {
	print colored("       $money","$sbtcolor4 on_$sbtcolor5");
	} elsif ($money >= 10) {
	print colored("        $money","$sbtcolor4 on_$sbtcolor5");
	} elsif ($money >= 1) {
	print colored("         $money","$sbtcolor4 on_$sbtcolor5");
	} else {
	print colored("         $money","$sbtcolor4 on_$sbtcolor5");
	}
	sep;
}

sub sbtdwinnings {
	sep;
	if ($sbtmoney > 9999999999) {
	print colored(sprintf("%.4e", $sbtmoney),"$sbtcolor4 on_$sbtcolor5");
	} elsif ($sbtmoney >= 1000000000) {
	print colored("$sbtmoney","$sbtcolor4 on_$sbtcolor5");
	} elsif ($sbtmoney >= 100000000) {
	print colored(" $sbtmoney","$sbtcolor4 on_$sbtcolor5");
	} elsif ($sbtmoney >= 10000000) {
	print colored("  $sbtmoney","$sbtcolor4 on_$sbtcolor5");
	} elsif ($sbtmoney >= 1000000) {
	print colored("   $sbtmoney","$sbtcolor4 on_$sbtcolor5");
	} elsif ($sbtmoney >= 100000) {
	print colored("    $sbtmoney","$sbtcolor4 on_$sbtcolor5");
	} elsif ($sbtmoney >= 10000) {
	print colored("     $sbtmoney","$sbtcolor4 on_$sbtcolor5");
	} elsif ($sbtmoney >= 1000) {
	print colored("      $sbtmoney","$sbtcolor4 on_$sbtcolor5");
	} elsif ($sbtmoney >= 100) {
	print colored("       $sbtmoney","$sbtcolor4 on_$sbtcolor5");
	} elsif ($sbtmoney >= 10) {
	print colored("        $sbtmoney","$sbtcolor4 on_$sbtcolor5");
	} elsif ($sbtmoney >= 1) {
	print colored("         $sbtmoney","$sbtcolor4 on_$sbtcolor5");
	} else {
	print colored("         $sbtmoney","$sbtcolor4 on_$sbtcolor5");
	}
	sep;
}

sub sbtmedian4 {
	sbtblock5();
	if ($sbtRtotal4 == 1) {
		print colored('   4   ',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('   4   ',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();
	if ($sbtRtotal5 == 1) {
		print colored('   5   ',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('   5   ',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();
	if ($sbtRtotal6 == 1) {
		print colored('   6   ',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('   6   ',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();
	if ($sbtRtotal7 == 1) {
		print colored('   7   ',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('   7   ',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();
	if ($sbtRtotal8 == 1) {
		print colored('   8   ',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('   8   ',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();
	if ($sbtRtotal9 == 1) {
		print colored('   9   ',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('   9   ',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();
	if ($sbtRtotal10 == 1) {
		print colored('  1 0  ',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('  1 0  ',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();			
}

sub sbtmedian5 {
	sbtblock5();
	if ($sbtRtotal4 == 1) {
		print colored('       ',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('       ',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();
	if ($sbtRtotal5 == 1) {
		print colored('       ',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('       ',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();
	if ($sbtRtotal6 == 1) {
		print colored('       ',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('       ',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();
	if ($sbtRtotal7 == 1) {
		print colored('       ',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('       ',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();
	if ($sbtRtotal8 == 1) {
		print colored('       ',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('       ',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();
	if ($sbtRtotal9 == 1) {
		print colored('       ',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('       ',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();
	if ($sbtRtotal10 == 1) {
		print colored('       ',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('       ',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();			
}

sub sbtmedian6 {
	sbtblock5();
	if ($sbtRtotal4 == 1) {
		print colored('PAYs61X',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('PAYs61X',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();
	if ($sbtRtotal5 == 1) {
		print colored('PAYs31X',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('PAYs31X',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();
	if ($sbtRtotal6 == 1) {
		print colored('PAYs19X',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('PAYs19X',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();
	if ($sbtRtotal7 == 1) {
		print colored('PAYs13X',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('PAYs13X',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();
	if ($sbtRtotal8 == 1) {
		print colored('PAYs 9X',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('PAYs 9X',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();
	if ($sbtRtotal9 == 1) {
		print colored('PAYs 8X',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('PAYs 8X',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();
	if ($sbtRtotal10 == 1) {
		print colored('PAYs 7X',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('PAYs 7X',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();			
}

#

sub sbtmedian7 {
	sbtblock5();
	if ($sbtRtotal11 == 1) {
		print colored('  1 1  ',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('  1 1  ',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();
	if ($sbtRtotal12 == 1) {
		print colored('  1 2  ',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('  1 2  ',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();
	if ($sbtRtotal13 == 1) {
		print colored('  1 3  ',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('  1 3  ',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();
	if ($sbtRtotal14 == 1) {
		print colored('  1 4  ',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('  1 4  ',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();
	if ($sbtRtotal15 == 1) {
		print colored('  1 5  ',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('  1 5  ',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();
	if ($sbtRtotal16 == 1) {
		print colored('  1 6  ',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('  1 6  ',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();
	if ($sbtRtotal17 == 1) {
		print colored('  1 7  ',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('  1 7  ',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();			
}

sub sbtmedian8 {
	sbtblock5();
	if ($sbtRtotal11 == 1) {
		print colored('       ',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('       ',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();
	if ($sbtRtotal12 == 1) {
		print colored('       ',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('       ',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();
	if ($sbtRtotal13 == 1) {
		print colored('       ',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('       ',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();
	if ($sbtRtotal14 == 1) {
		print colored('       ',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('       ',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();
	if ($sbtRtotal15 == 1) {
		print colored('       ',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('       ',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();
	if ($sbtRtotal16 == 1) {
		print colored('       ',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('       ',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();
	if ($sbtRtotal17 == 1) {
		print colored('       ',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('       ',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();			
}

sub sbtmedian9 {
	sbtblock5();
	if ($sbtRtotal11 == 1) {
		print colored('PAYs 7X',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('PAYs 7X',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();
	if ($sbtRtotal12 == 1) {
		print colored('PAYs 8X',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('PAYs 8X',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();
	if ($sbtRtotal13 == 1) {
		print colored('PAYs 9X',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('PAYs 9X',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();
	if ($sbtRtotal14 == 1) {
		print colored('PAYs13X',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('PAYs13X',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();
	if ($sbtRtotal15 == 1) {
		print colored('PAYs19X',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('PAYs19X',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();
	if ($sbtRtotal16 == 1) {
		print colored('PAYs31X',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('PAYs31X',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();
	if ($sbtRtotal17 == 1) {
		print colored('PAYs61X',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('PAYs61X',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();			
}

sub sbtmedian11 {
	sbtblock5();
	print colored(' L ',"$sbtcolor6 on_$sbtcolor7");
	if ($sbtRtotalSM == 1) {
		print colored('         ',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('         ',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();
	if ($sbtRtotalBG == 1) {
		print colored('         ',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('         ',"$sbtcolor10 on_$sbtcolor11");
	}
	print colored('   ',"$sbtcolor6 on_$sbtcolor7");
	sbtblock5();	
}

sub sbtmedian12 {
	sbtblock5();
	print colored(' L ',"$sbtcolor6 on_$sbtcolor7");
	if ($sbtRtotalSM == 1) {
		print colored(' PAYs 2X ',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored(' PAYs 2X ',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();
	if ($sbtRtotalBG == 1) {
		print colored(' Over 10 ',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored(' Over 10 ',"$sbtcolor10 on_$sbtcolor11");
	}
	print colored(' G ',"$sbtcolor6 on_$sbtcolor7");
	sbtblock5();	
}

sub sbtmedian13 {
	sbtblock5();
	print colored(' A ',"$sbtcolor6 on_$sbtcolor7");
	if ($sbtRtotalSM == 1) {
		print colored('  SANS   ',"$sbtcolor13 on_$sbtcolor9");	
	} else { 
		print colored('  SANS   ',"$sbtcolor14 on_$sbtcolor11");
	}
	sbtblock5();
	if ($sbtRtotalBG == 1) {
		print colored(' TRIPLETS',"$sbtcolor13 on_$sbtcolor9");	
	} else { 
		print colored(' TRIPLETS',"$sbtcolor14 on_$sbtcolor11");
	}
	print colored(' I ',"$sbtcolor6 on_$sbtcolor7");
	sbtblock5();	
}

sub sbtmedian14 {
	sbtblock5();
	print colored(' M ',"$sbtcolor6 on_$sbtcolor7");
	if ($sbtRtotalSM == 1) {
		print colored(' Under 11',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored(' Under 11',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();
	if ($sbtRtotalBG == 1) {
		print colored(' PAYs 2X ',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored(' PAYs 2X ',"$sbtcolor10 on_$sbtcolor11");
	}
	print colored(' B ',"$sbtcolor6 on_$sbtcolor7");
	sbtblock5();	
}

sub sbtmedian15 {
	sbtblock5();
	print colored(' S ',"$sbtcolor6 on_$sbtcolor7");
	if ($sbtRtotalSM == 1) {
		print colored('         ',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('         ',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();
	if ($sbtRtotalBG == 1) {
		print colored('         ',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('         ',"$sbtcolor10 on_$sbtcolor11");
	}
	print colored('   ',"$sbtcolor6 on_$sbtcolor7");
	sbtblock5();	
}

sub sbtmedian16 {
	print colored(' ANY ',"$sbtcolor6 on_$sbtcolor7");
	sbtblock5();	
}

sub sbtmedian17 {
	if ($sbtRtotalANYTRI == 1) {
		print colored('  P T',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('  P T',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();	
}

sub sbtmedian18 {
	if ($sbtRtotalANYTRI == 1) {
		print colored('  A R',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('  A R',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();	
}

sub sbtmedian19 {
	if ($sbtRtotalANYTRI == 1) {
		print colored('A Y I',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('A Y I',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();	
}

sub sbtmedian20 {
	if ($sbtRtotalANYTRI == 1) {
		print colored('N   P',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('N   P',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();	
}

sub sbtmedian21 {
	if ($sbtRtotalANYTRI == 1) {
		print colored('Y 3 L',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('Y 3 L',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();	
}

sub sbtmedian22 {
	if ($sbtRtotalANYTRI == 1) {
		print colored('  1 E',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('  1 E',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();	
}

sub sbtmedian23 {
	if ($sbtRtotalANYTRI == 1) {
		print colored('  X T',"$sbtcolor8 on_$sbtcolor9");	
	} else { 
		print colored('  X T',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();	
}

sub sbtmedian24 {
	print colored(' TRI ',"$sbtcolor6 on_$sbtcolor7");
	sbtblock5();	
}

sub sbtmedian25 {
	sbtblock5();
	print colored('   T  R  I  P  L  E  T   ',"$sbtcolor6 on_$sbtcolor7");
	sbtblock5();	 
}

sub sbtmedian26 {
	sbtblock5();
	if ($sbtRtotalSPFTRI == 1) {
		print colored(' P A Y s   ',"$sbtcolor8 on_$sbtcolor9");
		print colored('111',"$sbtcolor15 on_$sbtcolor16");
		print colored('    1 8 0 X',"$sbtcolor8 on_$sbtcolor9");
	} elsif ($sbtRtotalSPFTRI == 2) {
		print colored(' P A Y s   ',"$sbtcolor8 on_$sbtcolor9");
		print colored('222',"$sbtcolor15 on_$sbtcolor16");
		print colored('    1 8 0 X',"$sbtcolor8 on_$sbtcolor9");
	} elsif ($sbtRtotalSPFTRI == 3) {
		print colored(' P A Y s   ',"$sbtcolor8 on_$sbtcolor9");
		print colored('333',"$sbtcolor15 on_$sbtcolor16");
		print colored('    1 8 0 X',"$sbtcolor8 on_$sbtcolor9");
	} elsif ($sbtRtotalSPFTRI == 4) {
		print colored(' P A Y s   ',"$sbtcolor8 on_$sbtcolor9");
		print colored('444',"$sbtcolor15 on_$sbtcolor16");
		print colored('    1 8 0 X',"$sbtcolor8 on_$sbtcolor9");
	} elsif ($sbtRtotalSPFTRI == 5) {
		print colored(' P A Y s   ',"$sbtcolor8 on_$sbtcolor9");
		print colored('555',"$sbtcolor15 on_$sbtcolor16");
		print colored('    1 8 0 X',"$sbtcolor8 on_$sbtcolor9");
	} elsif ($sbtRtotalSPFTRI == 6) {
		print colored(' P A Y s   ',"$sbtcolor8 on_$sbtcolor9");
		print colored('666',"$sbtcolor15 on_$sbtcolor16");
		print colored('    1 8 0 X',"$sbtcolor8 on_$sbtcolor9");				
	} else { 
		print colored(' P A Y s   ',"$sbtcolor10 on_$sbtcolor11");
		print colored('---',"$sbtcolor15 on_$sbtcolor16");
		print colored('    1 8 0 X',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();	
}

sub sbtmedian27 {
	sbtblock5();
	print colored(' S  P  E  C  I  F  I  C  ',"$sbtcolor6 on_$sbtcolor7");
	sbtblock5();	 
}

sub sbtmedian28 {
	sbtblock5();
	if ($sbtRtotalSPFDOB == 1) {
		print colored(' P A Y s   ',"$sbtcolor8 on_$sbtcolor9");
		print colored('1-1',"$sbtcolor15 on_$sbtcolor16");
		print colored('      1 1 X',"$sbtcolor8 on_$sbtcolor9");
	} elsif ($sbtRtotalSPFDOB == 2) {
		print colored(' P A Y s   ',"$sbtcolor8 on_$sbtcolor9");
		print colored('2-2',"$sbtcolor15 on_$sbtcolor16");
		print colored('      1 1 X',"$sbtcolor8 on_$sbtcolor9");
	} elsif ($sbtRtotalSPFDOB == 3) {
		print colored(' P A Y s   ',"$sbtcolor8 on_$sbtcolor9");
		print colored('3-3',"$sbtcolor15 on_$sbtcolor16");
		print colored('      1 1 X',"$sbtcolor8 on_$sbtcolor9");
	} elsif ($sbtRtotalSPFDOB == 4) {
		print colored(' P A Y s   ',"$sbtcolor8 on_$sbtcolor9");
		print colored('4-4',"$sbtcolor15 on_$sbtcolor16");
		print colored('      1 1 X',"$sbtcolor8 on_$sbtcolor9");
	} elsif ($sbtRtotalSPFDOB == 5) {
		print colored(' P A Y s   ',"$sbtcolor8 on_$sbtcolor9");
		print colored('5-5',"$sbtcolor15 on_$sbtcolor16");
		print colored('      1 1 X',"$sbtcolor8 on_$sbtcolor9");
	} elsif ($sbtRtotalSPFDOB == 6) {
		print colored(' P A Y s   ',"$sbtcolor8 on_$sbtcolor9");
		print colored('6-6',"$sbtcolor15 on_$sbtcolor16");
		print colored('      1 1 X',"$sbtcolor8 on_$sbtcolor9");				
	} else { 
		print colored(' P A Y s   ',"$sbtcolor10 on_$sbtcolor11");
		print colored('---',"$sbtcolor15 on_$sbtcolor16");
		print colored('      1 1 X',"$sbtcolor10 on_$sbtcolor11");
	}
	sbtblock5();	
}

sub sbtmedian29 {
	sbtblock5();                            
	print colored('     D  O  U  B  L  E    ',"$sbtcolor6 on_$sbtcolor7");
	sbtblock5();	 
}

sub sbtmedian30 {
	sbtblock5();                            
	print colored('  N U M B E R   B E T  ',"$sbtcolor6 on_$sbtcolor7");
	print colored('                  ',"$sbtcolor0 on_$sbtcolor1");	 
}

sub sbtmedian31 {
	sbtblock5();
	if ($sbtRtotalNUMBER == 1) {
		print colored('PAYs 2X 3X or 11X on ',"$sbtcolor8 on_$sbtcolor9");
		print colored('1',"$sbtcolor21 on_$sbtcolor22");
		print colored(' ',"$sbtcolor8 on_$sbtcolor9");
	} elsif ($sbtRtotalNUMBER == 2) {
		print colored('PAYs 2X 3X or 11X on ',"$sbtcolor8 on_$sbtcolor9");
		print colored('2',"$sbtcolor21 on_$sbtcolor22");
		print colored(' ',"$sbtcolor8 on_$sbtcolor9");
	} elsif ($sbtRtotalNUMBER == 3) {
		print colored('PAYs 2X 3X or 11X on ',"$sbtcolor8 on_$sbtcolor9");
		print colored('3',"$sbtcolor21 on_$sbtcolor22");
		print colored(' ',"$sbtcolor8 on_$sbtcolor9");
	} elsif ($sbtRtotalNUMBER == 4) {
		print colored('PAYs 2X 3X or 11X on ',"$sbtcolor8 on_$sbtcolor9");
		print colored('4',"$sbtcolor21 on_$sbtcolor22");
		print colored(' ',"$sbtcolor8 on_$sbtcolor9");
	} elsif ($sbtRtotalNUMBER == 5) {
		print colored('PAYs 2X 3X or 11X on ',"$sbtcolor8 on_$sbtcolor9");
		print colored('5',"$sbtcolor21 on_$sbtcolor22");
		print colored(' ',"$sbtcolor8 on_$sbtcolor9");
	} elsif ($sbtRtotalNUMBER == 6) {
		print colored('PAYs 2X 3X or 11X on ',"$sbtcolor8 on_$sbtcolor9");
		print colored('6',"$sbtcolor21 on_$sbtcolor22");
		print colored(' ',"$sbtcolor8 on_$sbtcolor9");		
	} else {
		print colored('PAYs 2X 3X or 11X on ',"$sbtcolor10 on_$sbtcolor11");
		print colored('-',"$sbtcolor21 on_$sbtcolor22");
		print colored(' ',"$sbtcolor10 on_$sbtcolor11");
	}
}

sub sbtmedian0 {
	print colored('/------------------------------------------------------------------------------\\',"$sbtcolor0 on_$sbtcolor1");
}

sub sbtmedian1 {
	print colored('|-----------------------------------/',"$sbtcolor0 on_$sbtcolor1");
}

sub sbtmedian2 {
	print colored('\\---------------------------------------------------------------',"$sbtcolor0 on_$sbtcolor1");
}

sub sbtmedian3 {                                                                #
	print colored('                                                         ',"$sbtcolor12 on_$sbtcolor1");
}

sub sbtmedian10 {                                                               
	print colored('                           ',"$sbtcolor12 on_$sbtcolor1");
}

sub sbtblock0 {
	print colored('|',"$sbtcolor0 on_$sbtcolor1");
}

sub sbtblock1 {
	print colored('   ',"$sbtcolor0 on_$sbtcolor1");
}

sub sbtblock2 {
	print colored('                                   ',"$sbtcolor0 on_$sbtcolor1");
}

sub sbtblock3 {
	print colored('           ',"$sbtcolor0 on_$sbtcolor1");
}

sub sbtblock4 {
	print colored('        Sic Bo Tai Sai      ',"$sbtcolor3 on_$sbtcolor1");
	print colored(' BET',"$sbtcolor0 on_$sbtcolor1");
}

sub sbtblock5 {
	print colored(' ',"$sbtcolor0 on_$sbtcolor1");
}

sub sbtblock6 {
	print colored(' TOTAL ',"$sbtcolor6 on_$sbtcolor7");
}

sub sbtblock7 {
	print colored('FUNDS',"$sbtcolor0 on_$sbtcolor1");
}

sub sbtblock8 {
	print colored('WINNINGS',"$sbtcolor0 on_$sbtcolor1");
}

sub sbtblock9 {
	print colored('                                          ',"$sbtcolor0 on_$sbtcolor1");
}

sub sbtblock10 {
	print colored('---------------/',"$sbtcolor17 on_$sbtcolor18");
}

sub sbtblock11 {
	print colored('/--------------|',"$sbtcolor17 on_$sbtcolor18");
}

sub sbtblock12 {
	print colored('|',"$sbtcolor17 on_$sbtcolor18");
}

sub sbtswitch1 {
	$sbtnumber = $sbtdrand1;
}

sub sbtswitch2 {
	$sbtnumber = $sbtdrand2;
}

sub sbtswitch3 {
	$sbtnumber = $sbtdrand3;
}



sub sbtcompprint1 {
	print colored("$sbtcompvar1","$sbtcolor19 on_$sbtcolor20");
}

sub sbtcompprint2 {
	print colored("$sbtcompvar2","$sbtcolor19 on_$sbtcolor20");
}

sub sbtcompprint3 {
	print colored("$sbtcompvar3","$sbtcolor19 on_$sbtcolor20");
}

sub sbtcompprint4 {
	print colored("$sbtcompvar4","$sbtcolor19 on_$sbtcolor20");
}

sub sbtcompprint5 {
	print colored("$sbtcompvar5","$sbtcolor19 on_$sbtcolor20");
}

sub sbtcompprint6 {
	print colored("$sbtcompvar6","$sbtcolor19 on_$sbtcolor20");
}

sub sbtcompprint7 {
	print colored("$sbtcompvar7","$sbtcolor19 on_$sbtcolor20");
}

sub sbtcompprint8 {
	print colored("$sbtcompvar8","$sbtcolor19 on_$sbtcolor20");
}

sub sbtcompprint9 {
	print colored("$sbtcompvar9","$sbtcolor19 on_$sbtcolor20");
}

sub sbtcompprint10 {
	print colored("$sbtcompvar10","$sbtcolor19 on_$sbtcolor20");
}

sub sbtcompprint11 {
	print colored("$sbtcompvar11","$sbtcolor19 on_$sbtcolor20");
}

sub sbtcompprint12 {
	print colored("$sbtcompvar12","$sbtcolor19 on_$sbtcolor20");
}

sub sbtcompprint13 {
	print colored("$sbtcompvar13","$sbtcolor19 on_$sbtcolor20");
}

sub sbtcompprint14 {
	print colored("$sbtcompvar14","$sbtcolor19 on_$sbtcolor20");
}

sub sbtcompprint15 {
	print colored("$sbtcompvar15","$sbtcolor19 on_$sbtcolor20");
}

sub sbtcompprint16 {
	print colored("$sbtcompvar16","$sbtcolor19 on_$sbtcolor20");
}

sub sbtcompprint17 {
	print colored("$sbtcompvar17","$sbtcolor19 on_$sbtcolor20");
}

sub sbtcompprint18 {
	print colored("$sbtcompvar18","$sbtcolor19 on_$sbtcolor20");
}

sub sbtcompprint19 {
	print colored("$sbtcompvar19","$sbtcolor19 on_$sbtcolor20");
}

sub sbtcompprint20 {
	print colored("$sbtcompvar20","$sbtcolor19 on_$sbtcolor20");
}

sub sbtcompprint21 {
	print colored("$sbtcompvar21","$sbtcolor19 on_$sbtcolor20");
}

sub sbtcompvars1 {
	$sbtcompvar1 = '              ';
	$sbtcompvar2 = '  P = PLAY    ';
	$sbtcompvar3 = '              ';
	$sbtcompvar4 = '  B = CHANGE  ';
	$sbtcompvar5 = '      BET     ';
	$sbtcompvar6 = '              ';
	$sbtcompvar7 = '  N = CHANGE  ';
	$sbtcompvar8 = '      NUMBERS ';
	$sbtcompvar9 = '              ';
	$sbtcompvar10 = '  C = RETURN  ';
	$sbtcompvar11 = '      TO      ';
	$sbtcompvar12 = '      CASINO  ';
	$sbtcompvar13 = '      MENU    ';
	$sbtcompvar14 = '              ';
	$sbtcompvar15 = '  EXIT = QUIT ';
	$sbtcompvar16 = '              ';
	$sbtcompvar17 = '              ';
	$sbtcompvar18 = '              ';
	$sbtcompvar19 = '              ';
	$sbtcompvar20 = '              ';
	$sbtcompvar21 = '              ';
}

sub sbtcompvars2 {
	$sbtcompvar1 = 'To Play Number';
	$sbtcompvar2 = ' Enter N1..N6 ';	
	$sbtcompvar3 = 'To Play Big   ';
	$sbtcompvar4 = ' Enter BIG    ';
	$sbtcompvar5 = 'To Play Small ';
	$sbtcompvar6 = ' Enter SMALL  ';
	$sbtcompvar7 = '              ';
	$sbtcompvar8 = 'To Play Total ';
	$sbtcompvar9 = ' Enter T4..T17';
	$sbtcompvar10 = '              ';
	$sbtcompvar11 = 'To Play Any   ';
	$sbtcompvar12 = ' Triplet Enter';
	$sbtcompvar13 = ' ANYTRI       ';
	$sbtcompvar14 = '              ';
	$sbtcompvar15 = 'To Play A     ';
	$sbtcompvar16 = ' Specific Tri ';
	$sbtcompvar17 = ' Enter ST1.ST6';
	$sbtcompvar18 = '              ';
	$sbtcompvar19 = 'To Play A     ';
	$sbtcompvar20 = 'SpecificDouble';
	$sbtcompvar21 = 'Enter SD1..SD6';
}

sub sbtcompvars3 {
	$sbtcompvar1 = '              ';
	$sbtcompvar2 = '              ';
	$sbtcompvar3 = '  Enter Your  ';
	$sbtcompvar4 = '  Bet:        ';
	$sbtcompvar5 = '              ';
	$sbtcompvar6 = '              ';
	$sbtcompvar7 = '              ';
	$sbtcompvar8 = '              ';
	$sbtcompvar9 = '              ';
	$sbtcompvar10 = '              ';
	$sbtcompvar11 = '              ';
	$sbtcompvar12 = '              ';
	$sbtcompvar13 = '              ';
	$sbtcompvar14 = '              ';
	$sbtcompvar15 = '              ';
	$sbtcompvar16 = '              ';
	$sbtcompvar17 = '              ';
	$sbtcompvar18 = '              ';
	$sbtcompvar19 = '              ';
	$sbtcompvar20 = '              ';
	$sbtcompvar21 = '              ';
}

sub sbtthrowdice {
	$sbtdrand1 = ((int(rand(6))) + 1);
	$sbtdrand2 = ((int(rand(6))) + 1);
	$sbtdrand3 = ((int(rand(6))) + 1);
}

sub sbtdie0 { print colored('             ',"$sbtcolorD0 on_$sbtcolorD1"); }
sub sbtdie1 { print colored('      *      ',"$sbtcolorD0 on_$sbtcolorD1"); }
sub sbtdie2 { print colored('  *          ',"$sbtcolorD0 on_$sbtcolorD1"); }
sub sbtdie3 { print colored('          *  ',"$sbtcolorD0 on_$sbtcolorD1"); }
sub sbtdie4 { print colored('  *       *  ',"$sbtcolorD0 on_$sbtcolorD1"); }

sub sbtprintD0 {
		sbtdie0();
}

sub sbtprintD1 {
	if (($sbtnumber == 2) or ($sbtnumber == 3))  {
		sbtdie2();
	} elsif (($sbtnumber == 4) or ($sbtnumber == 5) or ($sbtnumber == 6))  {
		sbtdie4();	
	} else {
		sbtdie0();
	}
}

sub sbtprintD2 {
	if (($sbtnumber == 1) or ($sbtnumber == 3) or ($sbtnumber == 5))  {
		sbtdie1();
	} elsif ($sbtnumber == 6)  {
		sbtdie4();	
	} else {
		sbtdie0();
	}
}

sub sbtprintD3 {
	if (($sbtnumber == 2) or ($sbtnumber == 3))  {
		sbtdie3();
	} elsif (($sbtnumber == 4) or ($sbtnumber == 5) or ($sbtnumber == 6))  {
		sbtdie4();	
	} else {
		sbtdie0();
	}
}

sub sbtmainprint {
sbtmedian0(); print"\n";
sbtblock0(); sbtblock2(); sbtblock0();  sbtblock4(); sbtdbet(); sbtblock0(); print"\n";
sbtblock0(); sbtblock1(); sbtprintD0(); sbtblock1(); sbtprintD0(); sbtblock1(); sbtblock0(); sbtmedian30(); sbtblock0(); print"\n";
sbtblock0(); sbtblock1(); sbtswitch1(); sbtprintD1(); sbtblock1(); sbtswitch2(); sbtprintD1(); sbtblock1(); sbtblock0(); sbtmedian31(); sbtblock8(); sbtdwinnings(); sbtblock0(); print"\n";
sbtblock0(); sbtblock1(); sbtprintD0(); sbtblock1(); sbtprintD0(); sbtblock1(); sbtblock0(); sbtblock9(); sbtblock0(); print"\n";
sbtblock0(); sbtblock1(); sbtswitch1(); sbtprintD2(); sbtblock1(); sbtswitch2(); sbtprintD2(); sbtblock1(); sbtblock0(); sbtmedian27(); sbtblock7(); sbtdmoney(); sbtblock0(); print"\n";
sbtblock0(); sbtblock1(); sbtprintD0(); sbtblock1(); sbtprintD0(); sbtblock1(); sbtblock0(); sbtmedian28(); sbtblock11(); print"\n";
sbtblock0(); sbtblock1(); sbtswitch1(); sbtprintD3(); sbtblock1(); sbtswitch2(); sbtprintD3(); sbtblock1(); sbtblock0(); sbtmedian29(); sbtblock12(); sbtcompprint1(); sbtblock12(); print"\n";
sbtblock0(); sbtblock1(); sbtprintD0(); sbtblock1(); sbtprintD0(); sbtblock1(); sbtblock0(); sbtmedian10(); sbtblock12(); sbtcompprint2(); sbtblock12(); print"\n";
sbtblock0(); sbtblock2(); sbtblock0();  sbtmedian27(); sbtblock12(); sbtcompprint3(); sbtblock12(); print"\n";
sbtblock0(); sbtblock3(); sbtprintD0(); sbtblock3(); sbtblock0(); sbtmedian26(); sbtblock12(); sbtcompprint4(); sbtblock12(); print"\n";
sbtblock0(); sbtblock3(); sbtswitch3(); sbtprintD1(); sbtblock3(); sbtblock0(); sbtmedian25(); sbtblock12(); sbtcompprint5(); sbtblock12(); print"\n";
sbtblock0(); sbtblock3(); sbtprintD0(); sbtblock3(); sbtblock0(); sbtmedian10(); sbtblock12(); sbtcompprint6(); sbtblock12(); print"\n";
sbtblock0(); sbtblock3(); sbtswitch3(); sbtprintD2(); sbtblock3(); sbtblock0(); sbtmedian15(); sbtblock12(); sbtcompprint7(); sbtblock12(); print"\n";
sbtblock0(); sbtblock3(); sbtprintD0(); sbtblock3(); sbtblock0(); sbtmedian14();  sbtblock12(); sbtcompprint8(); sbtblock12(); print"\n";
sbtblock0(); sbtblock3(); sbtswitch3(); sbtprintD3(); sbtblock3(); sbtblock0(); sbtmedian13(); sbtblock12(); sbtcompprint9(); sbtblock12(); print"\n";
sbtblock0(); sbtblock3(); sbtprintD0(); sbtblock3(); sbtblock0(); sbtmedian12();  sbtblock12(); sbtcompprint10(); sbtblock12(); print"\n";
sbtblock0(); sbtblock2(); sbtblock0(); sbtmedian11(); sbtblock12(); sbtcompprint11(); sbtblock12(); print"\n";
sbtmedian1(); sbtmedian10(); sbtblock12(); sbtcompprint12(); sbtblock12(); print"\n";

sbtblock0(); 
sbtblock5(); sbtblock6(); 
sbtblock5(); sbtblock6();
sbtblock5(); sbtblock6(); 
sbtblock5(); sbtblock6();
sbtblock5(); sbtblock6(); 
sbtblock5(); sbtblock6();
sbtblock5(); sbtblock6(); 
sbtblock5(); sbtmedian16(); sbtblock12(); sbtcompprint13(); sbtblock12(); print"\n";

sbtblock0(); sbtmedian4(); sbtmedian17(); sbtblock12(); sbtcompprint14(); sbtblock12(); print"\n";
sbtblock0(); sbtmedian5(); sbtmedian18(); sbtblock12(); sbtcompprint15(); sbtblock12(); print"\n";
sbtblock0(); sbtmedian6(); sbtmedian19(); sbtblock12(); sbtcompprint16(); sbtblock12(); print"\n";
sbtblock0(); sbtmedian3(); sbtmedian20(); sbtblock12(); sbtcompprint17(); sbtblock12(); print"\n";

sbtblock0(); 
sbtblock5(); sbtblock6(); 
sbtblock5(); sbtblock6();
sbtblock5(); sbtblock6(); 
sbtblock5(); sbtblock6();
sbtblock5(); sbtblock6(); 
sbtblock5(); sbtblock6();
sbtblock5(); sbtblock6(); 
sbtblock5(); sbtmedian21(); sbtblock12(); sbtcompprint18(); sbtblock12(); print"\n";

sbtblock0(); sbtmedian7(); sbtmedian22(); sbtblock12(); sbtcompprint19(); sbtblock12(); print"\n";
sbtblock0(); sbtmedian8(); sbtmedian23(); sbtblock12(); sbtcompprint20(); sbtblock12(); print"\n";
sbtblock0(); sbtmedian9(); sbtmedian24(); sbtblock12(); sbtcompprint21(); sbtblock12(); print"\n";
sbtmedian2(); sbtblock10(); print"\n"
}
################################################################################################################################


################################################################################################################################
## GENRE: Dice
## NAME: Casino Craps
## AUTHOR: MikeeUSA

sub ccrapsresetnum {
	$ccrapsRtotalAC = 0;
	$ccrapsRtotalA7 = 0;
	$ccrapsRtotalFI = 0;
	$ccrapsRtotalPL = 0;
	$ccrapsRtotalDPL = 0;
	$ccrapsRtotalBIG6 = 0;
	$ccrapsRtotalBIG8 = 0;
	$ccrapsRtotalH10 = 0;
	$ccrapsRtotalH8 = 0;
	$ccrapsRtotalH6 = 0;
	$ccrapsRtotalH4 = 0;
	$ccrapsRtotalO2 = 0;
	$ccrapsRtotalO3 = 0;
	$ccrapsRtotalO11 = 0;
	$ccrapsRtotalO12 = 0;	
}

sub ccrapsnewgameset {
	$ccrapsnumberofrolls = 0;
	$ccrapspoint = 0; #Hasn't been decided
}

sub ccrapsnewgamesetall {
	ccrapsnewgameset();
	$ccrapscraps = 0;
	$ccrapslose = 0;
	$ccrapswin = 0;
	$ccrapstie = 0;
	$ccrapsnumberofrolls = 0;
}

sub ccrapscrapsrolled1 {
	if ($ccrapscraps == 1) {
		ccrapsnewgameset();	
	}
}

sub ccrapscrapsrolled2 {
	if ($ccrapscraps == 1) {
		$ccrapscraps = 0;	
	}
}

sub ccrapsloserolled1 {
	if ($ccrapslose == 1) {
		ccrapsnewgameset();	
	}
}

sub ccrapsloserolled2 {
	if ($ccrapslose == 1) {
		$ccrapslose = 0;	
	}
}

sub ccrapswinrolled1 {
	if ($ccrapswin == 1) {
		ccrapsnewgameset();	
	}
}

sub ccrapswinrolled2 {
	if ($ccrapswin == 1) {
		$ccrapswin = 0;	
	}
}

sub ccrapstierolled1 {
	if ($ccrapstie == 1) {
		ccrapsnewgameset();	
	}
}

sub ccrapstierolled2 {
	if ($ccrapstie == 1) {
		$ccrapstie	= 0;
	}
}

sub ccrapsnfrnc {
	if ($ccrapsnumberofrolls != 0) {
		$ccrapscraps = 0;
	}
}

sub ccrapsmainspin1 {
	ccrapscrapsrolled2();
	ccrapsloserolled2();
	ccrapswinrolled2();
	ccrapstierolled2();
	ccrapsreset();
	ccrapscolors();
	ccrapsscrollset1();
	
	if ($animate == 1) {
		$ccrapscolorD0 = $ccrapscolorD2;
		
		ccrapsthrowdice();
		ccrapsmainprint();
		p7pause();
		newlines();
		
		ccrapsthrowdice();
		ccrapsmainprint();
		p7pause();
		newlines();
		
		ccrapsthrowdice();
		ccrapsmainprint();
		p7pause();
		newlines();
		
		ccrapsthrowdice();
		ccrapsmainprint();
		p7pause();
		newlines();
		
		ccrapsthrowdice();
		ccrapsmainprint();
		p7pause();
		newlines();
		
		ccrapsthrowdice();
		ccrapsmainprint();
		p7pause();
		newlines();
		
		ccrapsthrowdice();
		ccrapsmainprint();
		p7pause();
		newlines();
		
		ccrapscolors();
	}

	ccrapsthrowdice();
	ccrapsaddmoney();
	ccrapsmainprint();	
	ptracker();
	ccrapscrapsrolled1();
	ccrapsloserolled1();
	ccrapswinrolled1();
	ccrapstierolled1();
	ccrapsstdin1();	
}

sub ccrapsmainspin2 {
	ccrapsreset();
	ccrapscolors();
	ccrapsscrollset1();
	ccrapsmainprint();		
	ccrapsstdin1();
}

sub ccrapsmainspin3 {
	ccrapsreset();
	ccrapscolors();
	ccrapsscrollset2();
	ccrapsmainprint();	
	$ccrapsstart2 = <STDIN>;
	chomp($ccrapsstart2);
	ccrapsresetnum();
	if (($ccrapsstart2 eq 'o12') or ($ccrapsstart2 eq 'O12')) {
		$ccrapsstart2 = 'O12';
		$ccrapsRtotalO12 = 1;
	} elsif (($ccrapsstart2 eq 'o11') or ($ccrapsstart2 eq 'O11')) {
		$ccrapsstart2 = 'O11';
		$ccrapsRtotalO11 = 1;
	} elsif (($ccrapsstart2 eq 'o3') or ($ccrapsstart2 eq 'O3')) {
		$ccrapsstart2 = 'O3';
		$ccrapsRtotalO3 = 1;
	} elsif (($ccrapsstart2 eq 'o2') or ($ccrapsstart2 eq 'O2')) {
		$ccrapsstart2 = 'O2';
		$ccrapsRtotalO2 = 1;
	} elsif (($ccrapsstart2 eq 'ac') or ($ccrapsstart2 eq 'AC')) {
		$ccrapsstart2 = 'AC';
		$ccrapsRtotalAC = 1;
	} elsif (($ccrapsstart2 eq 'a7') or ($ccrapsstart2 eq 'A7')) {
		$ccrapsstart2 = 'A7';
		$ccrapsRtotalA7 = 1;
	} elsif (($ccrapsstart2 eq 'fi') or ($ccrapsstart2 eq 'FI')) {
		$ccrapsstart2 = 'FI';
		$ccrapsRtotalFI = 1;	
	} elsif (($ccrapsstart2 eq 'h4') or ($ccrapsstart2 eq 'H4')) {
		$ccrapsstart2 = 'H4';
		$ccrapsRtotalH4 = 1;
		ccrapsnewgamesetall(); #So player can't change his odds
	} elsif (($ccrapsstart2 eq 'h6') or ($ccrapsstart2 eq 'H6')) {
		$ccrapsstart2 = 'H6';
		$ccrapsRtotalH6 = 1;
		ccrapsnewgamesetall(); #So player can't change his odds
	} elsif (($ccrapsstart2 eq 'h8') or ($ccrapsstart2 eq 'H8')) {
		$ccrapsstart2 = 'H8';
		$ccrapsRtotalH8 = 1;
		ccrapsnewgamesetall(); #So player can't change his odds
	} elsif (($ccrapsstart2 eq 'h10') or ($ccrapsstart2 eq 'H10')) {
		$ccrapsstart2 = 'H10';
		$ccrapsRtotalH10 = 1;
		ccrapsnewgamesetall(); #So player can't change his odds
	} elsif (($ccrapsstart2 eq 'pl') or ($ccrapsstart2 eq 'PL')) {
		$ccrapsstart2 = 'PL';
		$ccrapsRtotalPL = 1;
		ccrapsnewgamesetall(); #So player can't change his odds
	} elsif (($ccrapsstart2 eq 'dpl') or ($ccrapsstart2 eq 'DPL')) {
		$ccrapsstart2 = 'DPL';
		$ccrapsRtotalDPL = 1;
		ccrapsnewgamesetall(); #So player can't change his odds
	} elsif (($ccrapsstart2 eq 'big6') or ($ccrapsstart2 eq 'BIG6')) {
		$ccrapsstart2 = 'BIG6';
		$ccrapsRtotalBIG6 = 1;
		ccrapsnewgamesetall(); #So player can't change his odds
	} elsif (($ccrapsstart2 eq 'big8') or ($ccrapsstart2 eq 'BIG8')) {
		$ccrapsstart2 = 'BIG8';
		$ccrapsRtotalBIG8 = 1;
		ccrapsnewgamesetall(); #So player can't change his odds								
	} else {
		$ccrapsstart2 = ' ';
	} 	
	newlines();
	ccrapsmainspin2();
}

sub ccrapsaddmoney {
	$ccrapsdrand4 = ("$ccrapsdrand1"."$ccrapsdrand2");
	$ccrapsadded = ($ccrapsdrand1 + $ccrapsdrand2);
	if ($ccrapspoint == 0) {
		if (($ccrapsadded != 2) and ($ccrapsadded != 3) and ($ccrapsadded != 12) and ($ccrapsadded != 7) and ($ccrapsadded != 11)) {
			$ccrapspoint = $ccrapsadded;
		}
	}
	
	if (($ccrapsadded == 2) or ($ccrapsadded == 3) or ($ccrapsadded == 12)) {
		$ccrapscraps = 1;
	}
	
	if ((($ccrapsadded == 2) or ($ccrapsadded == 3) or ($ccrapsadded == 12)) && ($ccrapsstart2 eq 'AC')) {
		$ccrapsaddmoney = $ccrapsbet * 8;
		$ccrapsstwin = $ccrapsstwin + 1;
	} elsif (($ccrapsadded == 7) && ($ccrapsstart2 eq 'A7')) {
		$ccrapsaddmoney = $ccrapsbet * 5;
		$ccrapsstwin = $ccrapsstwin + 1;	
	} elsif (($ccrapsadded == 11) && ($ccrapsstart2 eq 'O11')) {
		$ccrapsaddmoney = $ccrapsbet * 17;
		$ccrapsstwin = $ccrapsstwin + 1;
	} elsif (($ccrapsadded == 12) && ($ccrapsstart2 eq 'O12')) {
		$ccrapsaddmoney = $ccrapsbet * 31;
		$ccrapsstwin = $ccrapsstwin + 1;
	} elsif (($ccrapsadded == 2) && ($ccrapsstart2 eq 'O2')) {
		$ccrapsaddmoney = $ccrapsbet * 30;
		$ccrapsstwin = $ccrapsstwin + 1;
	} elsif (($ccrapsadded == 3) && ($ccrapsstart2 eq 'O3')) {
		$ccrapsaddmoney = $ccrapsbet * 16;
		$ccrapsstwin = $ccrapsstwin + 1;
	} elsif (($ccrapsadded == 2) && ($ccrapsstart2 eq 'FI')) {
		$ccrapsaddmoney = $ccrapsbet * 3;
		$ccrapsstwin = $ccrapsstwin + 1;
	} elsif (($ccrapsadded == 12) && ($ccrapsstart2 eq 'FI')) {
		$ccrapsaddmoney = $ccrapsbet * 3;
		$ccrapsstwin = $ccrapsstwin + 1;	
	} elsif (($ccrapsadded == 3) && ($ccrapsstart2 eq 'FI')) {
		$ccrapsaddmoney = $ccrapsbet * 2;
		$ccrapsstwin = $ccrapsstwin + 1;
	} elsif (($ccrapsadded == 4) && ($ccrapsstart2 eq 'FI')) {
		$ccrapsaddmoney = $ccrapsbet * 2;
		$ccrapsstwin = $ccrapsstwin + 1;
	} elsif (($ccrapsadded == 9) && ($ccrapsstart2 eq 'FI')) {
		$ccrapsaddmoney = $ccrapsbet * 2;
		$ccrapsstwin = $ccrapsstwin + 1;
	} elsif (($ccrapsadded == 10) && ($ccrapsstart2 eq 'FI')) {
		$ccrapsaddmoney = $ccrapsbet * 2;
		$ccrapsstwin = $ccrapsstwin + 1;				
	} elsif (($ccrapsadded == 11) && ($ccrapsstart2 eq 'FI')) {
		$ccrapsaddmoney = $ccrapsbet * 2;
		$ccrapsstwin = $ccrapsstwin + 1;
	} elsif ($ccrapsstart2 eq 'BIG6') {
		ccrapsnfrnc(); #not first roll, thus not craps
		if ($ccrapsnumberofrolls == 0) {
			if (($ccrapsadded == 7)) {
				$ccrapslose = 1;
				$ccrapsaddmoney = 0;
				$ccrapsstlose = $ccrapsstlose + 1;
			} elsif ($ccrapscraps == 1) {
				$ccrapslose = 1;
				$ccrapsaddmoney = 0;
				$ccrapsstlose = $ccrapsstlose + 1;
			} else {
				$ccrapsaddmoney = 0;
			}
		} else {
			if ($ccrapsadded == 7) {
				$ccrapslose = 1;
				$ccrapsaddmoney = 0;
				$ccrapsstlose = $ccrapsstlose + 1;
			} elsif ($ccrapsadded == 6) {
				$ccrapswin = 1;
				$ccrapsaddmoney = $ccrapsbet * 2;
				$ccrapsstwin = $ccrapsstwin + 1;
			} else {
				$ccrapsaddmoney = 0;
			}
		}
	} elsif ($ccrapsstart2 eq 'BIG8') {
		ccrapsnfrnc(); #not first roll, thus not craps
		if ($ccrapsnumberofrolls == 0) {
			if (($ccrapsadded == 7)) {
				$ccrapslose = 1;
				$ccrapsaddmoney = 0;
				$ccrapsstlose = $ccrapsstlose + 1;
			} elsif ($ccrapscraps == 1) {
				$ccrapslose = 1;
				$ccrapsaddmoney = 0;
				$ccrapsstlose = $ccrapsstlose + 1;
			} else {
				$ccrapsaddmoney = 0;
			}
		} else {
			if ($ccrapsadded == 8) {
				$ccrapslose = 1;
				$ccrapsaddmoney = 0;
				$ccrapsstlose = $ccrapsstlose + 1;
			} elsif ($ccrapsadded == 6) {
				$ccrapswin = 1;
				$ccrapsaddmoney = $ccrapsbet * 2;
				$ccrapsstwin = $ccrapsstwin + 1;
			} else {
				$ccrapsaddmoney = 0;
			}
		}
	} elsif ($ccrapsstart2 eq 'PL') {
		ccrapsnfrnc(); #not first roll, thus not craps
		if ($ccrapsnumberofrolls == 0) {
			if (($ccrapsadded == 11) or ($ccrapsadded == 7)) {
				$ccrapscraps = 0;
				$ccrapswin = 1;
				$ccrapsaddmoney = $ccrapsbet * 2;
				$ccrapsstwin = $ccrapsstwin + 1;
			} elsif ($ccrapscraps == 1) {
				$ccrapslose = 1;
				$ccrapsaddmoney = 0;
				$ccrapsstlose = $ccrapsstlose + 1;
			} else {
				$ccrapsaddmoney = 0;
			}
		} else {
			if ($ccrapsadded == 7) {
				$ccrapslose = 1;
				$ccrapsaddmoney = 0;
				$ccrapsstlose = $ccrapsstlose + 1;
			} elsif ($ccrapsadded == $ccrapspoint) {
				$ccrapswin = 1;
				$ccrapsaddmoney = $ccrapsbet * 2;
				$ccrapsstwin = $ccrapsstwin + 1;
			} else {
				$ccrapsaddmoney = 0;
			}
		}
	} elsif ($ccrapsstart2 eq 'DPL') {
		ccrapsnfrnc(); #not first roll, thus not craps
		if ($ccrapsnumberofrolls == 0) {
			if (($ccrapsadded == 11) or ($ccrapsadded == 7)) {
				$ccrapslose = 1;
				$ccrapsaddmoney = 0;
				$ccrapsstlose = $ccrapsstlose + 1;
			} elsif ($ccrapsadded == 12) {
				$ccrapstie = 1;
				$ccrapsaddmoney = $ccrapsbet;
			} elsif ($ccrapscraps == 1) {
				$ccrapscraps = 0;
				$ccrapswin = 1;
				$ccrapsaddmoney = $ccrapsbet * 2;
				$ccrapsstwin = $ccrapsstwin + 1;
			} else {
				$ccrapsaddmoney = 0;
			}
		} else {
			if ($ccrapsadded == 7) {
				$ccrapslose = 1;
				$ccrapsaddmoney = 0;
				$ccrapsstlose = $ccrapsstlose + 1;
			} elsif ($ccrapsadded == $ccrapspoint) {
				$ccrapswin = 1;
				$ccrapsaddmoney = $ccrapsbet * 2;
				$ccrapsstwin = $ccrapsstwin + 1;
			} else {
				$ccrapsaddmoney = 0;
			}
		}		
	} elsif ($ccrapsstart2 eq 'H4') {
		ccrapsnfrnc(); #not first roll, thus not craps
		if ($ccrapsdrand4 eq '22') {
			$ccrapswin = 1;
			$ccrapsaddmoney = $ccrapsbet * 9;
			$ccrapsstwin = $ccrapsstwin + 1;
		} elsif (($ccrapsadded == 4) or ($ccrapsadded == 7)) {
			$ccrapslose = 1;
			$ccrapsaddmoney = 0;
			$ccrapsstlose = $ccrapsstlose + 1;
		} elsif ($ccrapscraps == 1) {
			$ccrapslose = 1;
			$ccrapsaddmoney = 0;
			$ccrapsstlose = $ccrapsstlose + 1;
		} else {
			#Continue
			$ccrapsaddmoney = 0;
		}
	} elsif ($ccrapsstart2 eq 'H6') {
		ccrapsnfrnc(); #not first roll, thus not craps
		if ($ccrapsdrand4 eq '33') {
			$ccrapswin = 1;
			$ccrapsaddmoney = $ccrapsbet * 11;
			$ccrapsstwin = $ccrapsstwin + 1;
		} elsif (($ccrapsadded == 6) or ($ccrapsadded == 7)) {
			$ccrapslose = 1;
			$ccrapsaddmoney = 0;
			$ccrapsstlose = $ccrapsstlose + 1;
		} elsif ($ccrapscraps == 1) {
			$ccrapslose = 1;
			$ccrapsaddmoney = 0;
			$ccrapsstlose = $ccrapsstlose + 1;
		} else {
			#Continue
			$ccrapsaddmoney = 0;
		}
	} elsif ($ccrapsstart2 eq 'H8') {
		ccrapsnfrnc(); #not first roll, thus not craps
		if ($ccrapsdrand4 eq '44') {
			$ccrapswin = 1;
			$ccrapsaddmoney = $ccrapsbet * 10;
			$ccrapsstwin = $ccrapsstwin + 1;
		} elsif (($ccrapsadded == 8) or ($ccrapsadded == 7)) {
			$ccrapslose = 1;
			$ccrapsaddmoney = 0;
			$ccrapsstlose = $ccrapsstlose + 1;
		} elsif ($ccrapscraps == 1) {
			$ccrapslose = 1;
			$ccrapsaddmoney = 0;
			$ccrapsstlose = $ccrapsstlose + 1;
		} else {
			#Continue
			$ccrapsaddmoney = 0;
		}
	} elsif ($ccrapsstart2 eq 'H10') {
		ccrapsnfrnc(); #not first roll, thus not craps
		if ($ccrapsdrand4 eq '55') {
			$ccrapswin = 1;
			$ccrapsaddmoney = $ccrapsbet * 8;
			$ccrapsstwin = $ccrapsstwin + 1;
		} elsif (($ccrapsadded == 10) or ($ccrapsadded == 7)) {
			$ccrapslose = 1;
			$ccrapsaddmoney = 0;
			$ccrapsstlose = $ccrapsstlose + 1;
		} elsif ($ccrapscraps == 1) {
			$ccrapslose = 1;
			$ccrapsaddmoney = 0;
			$ccrapsstlose = $ccrapsstlose + 1;
		} else {
			#Continue
			$ccrapsaddmoney = 0;
		}
	} else {
		$ccrapsaddmoney = 0;
		$ccrapsstlose = $ccrapsstlose + 1;
	}
	$ccrapsnumberofrolls = $ccrapsnumberofrolls + 1;
	$ccrapsstmc = $ccrapsstmc + $ccrapsaddmoney;
	$ccrapsmoney = $ccrapsaddmoney;
	$money = $money + $ccrapsaddmoney;												
}

sub ccrapsreset {
	$ccrapsaddmoney = 0;
	$ccrapsmoney = 0; 
}

sub ccrapsmainspin4 {
	ccrapsreset();
	ccrapscolors();
	if (($ccrapsnumberofrolls > 0) and (($ccrapsstart2 eq 'BIG6') or ($ccrapsstart2 eq 'BIG8') or ($ccrapsstart2 eq 'PL') or ($ccrapsstart2 eq 'DPL') or ($ccrapsstart2 eq 'H4') or ($ccrapsstart2 eq 'H6') or ($ccrapsstart2 eq 'H8') or ($ccrapsstart2 eq 'H10'))) {
		ccrapsscrollset3a();
	} else {
		ccrapsscrollset3();
	}
	ccrapsmainprint();		
	$ccrapsstart3 = <STDIN>;
	chomp($ccrapsstart3);
	
	if (($ccrapsnumberofrolls > 0) and (($ccrapsstart2 eq 'BIG6') or ($ccrapsstart2 eq 'BIG8') or ($ccrapsstart2 eq 'PL') or ($ccrapsstart2 eq 'DPL') or ($ccrapsstart2 eq 'H4') or ($ccrapsstart2 eq 'H6') or ($ccrapsstart2 eq 'H8') or ($ccrapsstart2 eq 'H10'))) {
		#Not allowed to change bet while play is in progress
	} elsif ($ccrapsstart3 > $money) {
		$ccrapsbet = 0;
	} elsif ($ccrapsstart3 <= 0) {
		$ccrapsbet = 0;	 	
	} else {
		$ccrapsbet = sprintf("%.0f", $ccrapsstart3 )
	}	
	newlines();
	ccrapsmainspin2();
}

sub ccrapscolors {
	if ($ccrapssetup == 0) {
		ccrapscolorsblue();
	} elsif ($ccrapssetup == 1) {
		ccrapscolorsgreen();
	} else {
		ccrapscolorscyan();
	}
	
}

sub ccrapscolorsblue {
	$ccrapscolorD0 = "$boldwhite";
	$ccrapscolorD1 = "$bgcmagenta";
	$ccrapscolorD2 = "$white";	
	$ccrapscolor0 = "$boldblue"; #Table forground
	$ccrapscolor1 = "$bgcblue";  #Table background
	$ccrapscolor2 = "$yellow";
	$ccrapscolor3 = "$bgccyan";  #selection color
	$ccrapscolor4 = "$green";    #LCD forground
	$ccrapscolor5 = "$bgcblack"; #LCD Background
}

sub ccrapscolorsgreen {
	$ccrapscolorD0 = "$boldwhite";
	$ccrapscolorD1 = "$bgcmagenta";
	$ccrapscolorD2 = "$white";	
	$ccrapscolor0 = "$boldgreen"; #Table forground
	$ccrapscolor1 = "$bgcgreen";  #Table background
	$ccrapscolor2 = "$yellow";
	$ccrapscolor3 = "$bgcmagenta";  #selection color
	$ccrapscolor4 = "$green";    #LCD forground
	$ccrapscolor5 = "$bgcblack"; #LCD Background
}

sub ccrapscolorscyan {
	$ccrapscolorD0 = "$boldwhite";
	$ccrapscolorD1 = "$bgcblack";
	$ccrapscolorD2 = "$white";	
	$ccrapscolor0 = "$boldcyan"; #Table forground
	$ccrapscolor1 = "$bgccyan";  #Table background
	$ccrapscolor2 = "$yellow";
	$ccrapscolor3 = "$bgcblue";  #selection color
	$ccrapscolor4 = "$blue";    #LCD forground
	$ccrapscolor5 = "$bgcblack"; #LCD Background
}

sub ccrapsstdin1 {
	$ccrapsstart1 = <STDIN>;
	chomp($ccrapsstart1);
	if (($ccrapsstart1 eq 'P') or ($ccrapsstart1 eq 'p') or ($ccrapsstart1 eq 'a') or ($ccrapsstart1 eq 'A')) {
		if ($ccrapsstart2 eq ' ') {
			newlines();
			ccrapsmainspin2();
		} elsif ($ccrapsbet == 0) {
			newlines();
			ccrapsmainspin2();
		} elsif (($ccrapsnumberofrolls > 0) and (($ccrapsstart2 eq 'BIG6') or ($ccrapsstart2 eq 'BIG8') or ($ccrapsstart2 eq 'PL') or ($ccrapsstart2 eq 'DPL') or ($ccrapsstart2 eq 'H4') or ($ccrapsstart2 eq 'H6') or ($ccrapsstart2 eq 'H8') or ($ccrapsstart2 eq 'H10'))) {
			#Continuing our bet
			newlines();
			ccrapsmainspin1();
		} elsif ($money >= $ccrapsbet) {
			$money = $money - $ccrapsbet;
			$moneyexp = $moneyexp + $ccrapsbet;
			$ccrapsstmc2 = $ccrapsstmc2 + $ccrapsbet;
			$ccrapsstspins = $ccrapsstspins + 1;
			newlines();
			ccrapsmainspin1();
		} else {
			newlines();
			ccrapsmainspin2();
		}
	} elsif (($ccrapsstart1 eq 'N') or ($ccrapsstart1 eq 'n')) {
		newlines();
		ccrapsmainspin3();
	} elsif (($ccrapsstart1 eq 'B') or ($ccrapsstart1 eq 'b')) {
		newlines();
		ccrapsmainspin4();
	} elsif (($ccrapsstart1 eq 'C') or ($ccrapsstart1 eq 'c')) {
		return;
	} elsif (($ccrapsstart1 eq 'EXIT') or ($ccrapsstart1 eq 'exit') or ($ccrapsstart1 eq 'QUIT') or ($ccrapsstart1 eq 'quit')) {
		exitgame();	
	} else {
		newlines();
		ccrapsmainspin2();	
	}
}

sub ccrapsdbet {
	sep;
	if ($ccrapsbet > 9999999999) {
	print colored(sprintf("%.4e", $ccrapsbet),"$ccrapscolor4 on_$ccrapscolor5");
	} elsif ($ccrapsbet >= 1000000000) {
	print colored("$ccrapsbet","$ccrapscolor4 on_$ccrapscolor5");
	} elsif ($ccrapsbet >= 100000000) {
	print colored(" $ccrapsbet","$ccrapscolor4 on_$ccrapscolor5");
	} elsif ($ccrapsbet >= 10000000) {
	print colored("  $ccrapsbet","$ccrapscolor4 on_$ccrapscolor5");
	} elsif ($ccrapsbet >= 1000000) {
	print colored("   $ccrapsbet","$ccrapscolor4 on_$ccrapscolor5");
	} elsif ($ccrapsbet >= 100000) {
	print colored("    $ccrapsbet","$ccrapscolor4 on_$ccrapscolor5");
	} elsif ($ccrapsbet >= 10000) {
	print colored("     $ccrapsbet","$ccrapscolor4 on_$ccrapscolor5");
	} elsif ($ccrapsbet >= 1000) {
	print colored("      $ccrapsbet","$ccrapscolor4 on_$ccrapscolor5");
	} elsif ($ccrapsbet >= 100) {
	print colored("       $ccrapsbet","$ccrapscolor4 on_$ccrapscolor5");
	} elsif ($ccrapsbet >= 10) {
	print colored("        $ccrapsbet","$ccrapscolor4 on_$ccrapscolor5");
	} elsif ($ccrapsbet >= 1) {
	print colored("         $ccrapsbet","$ccrapscolor4 on_$ccrapscolor5");
	} else {
	print colored("         $ccrapsbet","$ccrapscolor4 on_$ccrapscolor5");
	}
	sep;
}

sub ccrapsdmoney {
	sep;
	if ($money > 9999999999) {
	print colored(sprintf("%.4e", $money),"$ccrapscolor4 on_$ccrapscolor5");
	} elsif ($money >= 1000000000) {
	print colored("$money","$ccrapscolor4 on_$ccrapscolor5");
	} elsif ($money >= 100000000) {
	print colored(" $money","$ccrapscolor4 on_$ccrapscolor5");
	} elsif ($money >= 10000000) {
	print colored("  $money","$ccrapscolor4 on_$ccrapscolor5");
	} elsif ($money >= 1000000) {
	print colored("   $money","$ccrapscolor4 on_$ccrapscolor5");
	} elsif ($money >= 100000) {
	print colored("    $money","$ccrapscolor4 on_$ccrapscolor5");
	} elsif ($money >= 10000) {
	print colored("     $money","$ccrapscolor4 on_$ccrapscolor5");
	} elsif ($money >= 1000) {
	print colored("      $money","$ccrapscolor4 on_$ccrapscolor5");
	} elsif ($money >= 100) {
	print colored("       $money","$ccrapscolor4 on_$ccrapscolor5");
	} elsif ($money >= 10) {
	print colored("        $money","$ccrapscolor4 on_$ccrapscolor5");
	} elsif ($money >= 1) {
	print colored("         $money","$ccrapscolor4 on_$ccrapscolor5");
	} else {
	print colored("         $money","$ccrapscolor4 on_$ccrapscolor5");
	}
	sep;
}

sub ccrapsdpoint {
	sep;
	if ($ccrapscraps == 1) {
	print colored('CRAPS!',"$ccrapscolor4 on_$ccrapscolor5");
	} elsif ($ccrapslose == 1) {
	print colored('  LOSE',"$ccrapscolor4 on_$ccrapscolor5");
	} elsif ($ccrapswin == 1) {
	print colored('  WIN!',"$ccrapscolor4 on_$ccrapscolor5");
	} elsif ($ccrapstie == 1) {
	print colored('   TIE',"$ccrapscolor4 on_$ccrapscolor5");
	} elsif ($ccrapspoint == 0) {
	print colored('   N/A',"$ccrapscolor4 on_$ccrapscolor5");
	} elsif ($ccrapspoint >= 10) {
	print colored("    $ccrapspoint","$ccrapscolor4 on_$ccrapscolor5");
	} elsif ($ccrapspoint >= 1) {
	print colored("     $ccrapspoint","$ccrapscolor4 on_$ccrapscolor5");
	} else {
	print colored("     $ccrapspoint","$ccrapscolor4 on_$ccrapscolor5");
	}
	sep;
}

sub ccrapsdtotal {
	sep;
	if ($ccrapsadded == 0) {
	print colored(' 0',"$ccrapscolor4 on_$ccrapscolor5");
	} elsif ($ccrapsadded  >= 10) {
	print colored("$ccrapsadded","$ccrapscolor4 on_$ccrapscolor5");
	} elsif ($ccrapsadded  >= 1) {
	print colored(" $ccrapsadded","$ccrapscolor4 on_$ccrapscolor5");
	} else {
	print colored(" $ccrapsadded","$ccrapscolor4 on_$ccrapscolor5");
	}
	sep;
}

sub ccrapsdwinnings {
	sep;
	if ($ccrapsmoney > 9999999999) {
	print colored(sprintf("%.4e", $ccrapsmoney),"$ccrapscolor4 on_$ccrapscolor5");
	} elsif ($ccrapsmoney >= 1000000000) {
	print colored("$ccrapsmoney","$ccrapscolor4 on_$ccrapscolor5");
	} elsif ($ccrapsmoney >= 100000000) {
	print colored(" $ccrapsmoney","$ccrapscolor4 on_$ccrapscolor5");
	} elsif ($ccrapsmoney >= 10000000) {
	print colored("  $ccrapsmoney","$ccrapscolor4 on_$ccrapscolor5");
	} elsif ($ccrapsmoney >= 1000000) {
	print colored("   $ccrapsmoney","$ccrapscolor4 on_$ccrapscolor5");
	} elsif ($ccrapsmoney >= 100000) {
	print colored("    $ccrapsmoney","$ccrapscolor4 on_$ccrapscolor5");
	} elsif ($ccrapsmoney >= 10000) {
	print colored("     $ccrapsmoney","$ccrapscolor4 on_$ccrapscolor5");
	} elsif ($ccrapsmoney >= 1000) {
	print colored("      $ccrapsmoney","$ccrapscolor4 on_$ccrapscolor5");
	} elsif ($ccrapsmoney >= 100) {
	print colored("       $ccrapsmoney","$ccrapscolor4 on_$ccrapscolor5");
	} elsif ($ccrapsmoney >= 10) {
	print colored("        $ccrapsmoney","$ccrapscolor4 on_$ccrapscolor5");
	} elsif ($ccrapsmoney >= 1) {
	print colored("         $ccrapsmoney","$ccrapscolor4 on_$ccrapscolor5");
	} else {
	print colored("         $ccrapsmoney","$ccrapscolor4 on_$ccrapscolor5");
	}
	sep;
}

sub ccrapsscrollset1 {
################                                                                            ##
$ccrapsscrolll1 = '                                    CASINO                                  ';
$ccrapsscrolll2 = ' P = Play                         CCCCC  RRRR     AA    PPPPP    SSSSS      ';
$ccrapsscrolll3 = ' B = Change Bet                  CC      RR  R   AAAA   PP   P  SS          ';
$ccrapsscrolll4 = ' N = Change Numbers              CC      RR  R  AA  AA  PPPPP    SSSS       ';
$ccrapsscrolll5 = ' C = Return to Casino Menu       CC      RRRR   AAAAAA  PP          SS      ';
$ccrapsscrolll6 = ' EXIT = Quit                      CCCCC  RR  R  AA  AA  PP      SSSSS       ';
$ccrapsscrolll7 = '                                              R                             ';
}

sub ccrapsscrollset2 {
################                                                                            ##
$ccrapsscrolll1 = ' To Play Big 6 or Big 8 enter BIG6 or BIG8                                  ';
$ccrapsscrolll2 = ' To Play a Hard Way bet enter H10, H8, H6, or H4                            ';
$ccrapsscrolll3 = ' To Play a One Roll bet enter O12, O11, O3, or O2                           ';
$ccrapsscrolll4 = ' To Play Pass Line enter PL                                                 ';
$ccrapsscrolll5 = ' To Play Don\'t Pass Line enter DPL                                          ';
$ccrapsscrolll6 = ' To Play AnyCraps enter AC                                                  ';
$ccrapsscrolll7 = ' To Play AnySevens enter A7                                                 ';
}

sub ccrapsscrollset3 {
################                                                                            ##
$ccrapsscrolll1 = '                                                                            ';
$ccrapsscrolll2 = ' Enter Your Bet:                                                            ';
$ccrapsscrolll3 = '                                                                            ';
$ccrapsscrolll4 = '                                                                            ';
$ccrapsscrolll5 = '                                                                            ';
$ccrapsscrolll6 = '                                                                            ';
$ccrapsscrolll7 = '                                                                            ';
}

sub ccrapsscrollset3a {
################                                                                            ##
$ccrapsscrolll1 = '                                                                            ';
$ccrapsscrolll2 = ' Cannot Change Bet While Play Is In Progress                                ';
$ccrapsscrolll3 = '                                                                            ';
$ccrapsscrolll4 = '                                                                            ';
$ccrapsscrolll5 = '                                                                            ';
$ccrapsscrolll6 = '                                                                            ';
$ccrapsscrolll7 = '                                                                            ';
}

sub ccrapsblockscroll1 {
print colored(' ',"$ccrapscolor0 on_$ccrapscolor1");
sep;
print colored("$ccrapsscrolll1","$ccrapscolor4 on_$ccrapscolor5");
sep;
print colored(' ',"$ccrapscolor0 on_$ccrapscolor1");
}

sub ccrapsblockscroll2 {
print colored(' ',"$ccrapscolor0 on_$ccrapscolor1");
sep;
print colored("$ccrapsscrolll2","$ccrapscolor4 on_$ccrapscolor5");
sep;
print colored(' ',"$ccrapscolor0 on_$ccrapscolor1");
}

sub ccrapsblockscroll3 {
print colored(' ',"$ccrapscolor0 on_$ccrapscolor1");
sep;
print colored("$ccrapsscrolll3","$ccrapscolor4 on_$ccrapscolor5");
sep;
print colored(' ',"$ccrapscolor0 on_$ccrapscolor1");
}

sub ccrapsblockscroll4 {
print colored(' ',"$ccrapscolor0 on_$ccrapscolor1");
sep;
print colored("$ccrapsscrolll4","$ccrapscolor4 on_$ccrapscolor5");
sep;
print colored(' ',"$ccrapscolor0 on_$ccrapscolor1");
}

sub ccrapsblockscroll5 {
print colored(' ',"$ccrapscolor0 on_$ccrapscolor1");
sep;
print colored("$ccrapsscrolll5","$ccrapscolor4 on_$ccrapscolor5");
sep;
print colored(' ',"$ccrapscolor0 on_$ccrapscolor1");
}

sub ccrapsblockscroll6 {
print colored(' ',"$ccrapscolor0 on_$ccrapscolor1");
sep;
print colored("$ccrapsscrolll6","$ccrapscolor4 on_$ccrapscolor5");
sep;
print colored(' ',"$ccrapscolor0 on_$ccrapscolor1");
}

sub ccrapsblockscroll7 {
print colored(' ',"$ccrapscolor0 on_$ccrapscolor1");
sep;
print colored("$ccrapsscrolll7","$ccrapscolor4 on_$ccrapscolor5");
sep;
print colored(' ',"$ccrapscolor0 on_$ccrapscolor1");
}

sub ccrapsblockhw0 {
	print colored('---------------',"$ccrapscolor0 on_$ccrapscolor1");
}

sub ccrapsblockhard4A {
	if ($ccrapsRtotalH4 == 1) {
		$buff0 = $ccrapscolor3
	} else {
		$buff0 = $ccrapscolor1;
	}
	print colored('H',"$boldwhite on_$buff0");
	print colored(' *    ',"$black on_$bgcwhite");
	print colored('P',"$ccrapscolor0 on_$buff0");
	print colored(' *    ',"$black on_$bgcwhite");
	print colored('9',"$ccrapscolor0 on_$buff0");
	$buff0 = '';
}

sub ccrapsblockhard4B {
	if ($ccrapsRtotalH4 == 1) {
		$buff0 = $ccrapscolor3
	} else {
		$buff0 = $ccrapscolor1;
	}
	print colored('4',"$boldwhite on_$buff0");
	print colored('      ',"$black on_$bgcwhite");
	print colored('A',"$ccrapscolor0 on_$buff0");
	print colored('      ',"$black on_$bgcwhite");
	print colored('X',"$ccrapscolor0 on_$buff0");
	$buff0 = '';
}

sub ccrapsblockhard4C {
	if ($ccrapsRtotalH4 == 1) {
		$buff0 = $ccrapscolor3
	} else {
		$buff0 = $ccrapscolor1;
	}
	print colored(' ',"$boldwhite on_$buff0");
	print colored('    * ',"$black on_$bgcwhite");
	print colored('Y',"$ccrapscolor0 on_$buff0");
	print colored('    * ',"$black on_$bgcwhite");
	print colored(' ',"$ccrapscolor0 on_$buff0");
	$buff0 = '';
}


sub ccrapsblockhard6A {
	if ($ccrapsRtotalH6 == 1) {
		$buff0 = $ccrapscolor3
	} else {
		$buff0 = $ccrapscolor1;
	}
	print colored('H',"$boldwhite on_$buff0");
	print colored(' *    ',"$black on_$bgcwhite");
	print colored('P',"$ccrapscolor0 on_$buff0");
	print colored(' *    ',"$black on_$bgcwhite");
	print colored('1',"$ccrapscolor0 on_$buff0");
	$buff0 = '';
}

sub ccrapsblockhard6B {
	if ($ccrapsRtotalH6 == 1) {
		$buff0 = $ccrapscolor3
	} else {
		$buff0 = $ccrapscolor1;
	}
	print colored('6',"$boldwhite on_$buff0");
	print colored('  *   ',"$black on_$bgcwhite");
	print colored('A',"$ccrapscolor0 on_$buff0");
	print colored('  *   ',"$black on_$bgcwhite");
	print colored('1',"$ccrapscolor0 on_$buff0");
	$buff0 = '';
}

sub ccrapsblockhard6C {
	if ($ccrapsRtotalH6 == 1) {
		$buff0 = $ccrapscolor3
	} else {
		$buff0 = $ccrapscolor1;
	}
	print colored(' ',"$boldwhite on_$buff0");
	print colored('    * ',"$black on_$bgcwhite");
	print colored('Y',"$ccrapscolor0 on_$buff0");
	print colored('    * ',"$black on_$bgcwhite");
	print colored('X',"$ccrapscolor0 on_$buff0");
	$buff0 = '';
}

sub ccrapsblockhard8A {
	if ($ccrapsRtotalH8 == 1) {
		$buff0 = $ccrapscolor3
	} else {
		$buff0 = $ccrapscolor1;
	}
	print colored('H',"$boldwhite on_$buff0");
	print colored(' *  * ',"$black on_$bgcwhite");
	print colored('P',"$ccrapscolor0 on_$buff0");
	print colored(' *  * ',"$black on_$bgcwhite");
	print colored('1',"$ccrapscolor0 on_$buff0");
	$buff0 = '';
}

sub ccrapsblockhard8B {
	if ($ccrapsRtotalH8 == 1) {
		$buff0 = $ccrapscolor3
	} else {
		$buff0 = $ccrapscolor1;
	}
	print colored('8',"$boldwhite on_$buff0");
	print colored('      ',"$black on_$bgcwhite");
	print colored('A',"$ccrapscolor0 on_$buff0");
	print colored('      ',"$black on_$bgcwhite");
	print colored('0',"$ccrapscolor0 on_$buff0");
	$buff0 = '';
}

sub ccrapsblockhard8C {
	if ($ccrapsRtotalH8 == 1) {
		$buff0 = $ccrapscolor3
	} else {
		$buff0 = $ccrapscolor1;
	}
	print colored(' ',"$boldwhite on_$buff0");
	print colored(' *  * ',"$black on_$bgcwhite");
	print colored('Y',"$ccrapscolor0 on_$buff0");
	print colored(' *  * ',"$black on_$bgcwhite");
	print colored('X',"$ccrapscolor0 on_$buff0");
	$buff0 = '';
}


sub ccrapsblockhard10A {
	if ($ccrapsRtotalH10 == 1) {
		$buff0 = $ccrapscolor3
	} else {
		$buff0 = $ccrapscolor1;
	}
	print colored('H',"$boldwhite on_$buff0");
	print colored(' *  * ',"$black on_$bgcwhite");
	print colored('P',"$ccrapscolor0 on_$buff0");
	print colored(' *  * ',"$black on_$bgcwhite");
	print colored('8',"$ccrapscolor0 on_$buff0");
	$buff0 = '';
}

sub ccrapsblockhard10B {
	if ($ccrapsRtotalH10 == 1) {
		$buff0 = $ccrapscolor3
	} else {
		$buff0 = $ccrapscolor1;
	}
	print colored('1',"$boldwhite on_$buff0");
	print colored('  *   ',"$black on_$bgcwhite");
	print colored('A',"$ccrapscolor0 on_$buff0");
	print colored('  *   ',"$black on_$bgcwhite");
	print colored('X',"$ccrapscolor0 on_$buff0");
	$buff0 = '';
}

sub ccrapsblockhard10C {
	if ($ccrapsRtotalH10 == 1) {
		$buff0 = $ccrapscolor3
	} else {
		$buff0 = $ccrapscolor1;
	}
	print colored('0',"$boldwhite on_$buff0");
	print colored(' *  * ',"$black on_$bgcwhite");
	print colored('Y',"$ccrapscolor0 on_$buff0");
	print colored(' *  * ',"$black on_$bgcwhite");
	print colored(' ',"$ccrapscolor0 on_$buff0");
	$buff0 = '';
}

sub ccrapsblockhw11A {
	if ($ccrapsRtotalO2 == 1) {
		$buff0 = $ccrapscolor3
	} else {
		$buff0 = $ccrapscolor1;
	}
	print colored('O',"$boldwhite on_$buff0");
	print colored('      ',"$black on_$bgcwhite");
	print colored('P',"$ccrapscolor0 on_$buff0");
	print colored('      ',"$black on_$bgcwhite");
	print colored('3',"$ccrapscolor0 on_$buff0");
	$buff0 = '';
}

sub ccrapsblockhw11B {
	if ($ccrapsRtotalO2 == 1) {
		$buff0 = $ccrapscolor3
	} else {
		$buff0 = $ccrapscolor1;
	}
	print colored('2',"$boldwhite on_$buff0");
	print colored('  *   ',"$black on_$bgcwhite");
	print colored('A',"$ccrapscolor0 on_$buff0");
	print colored('  *   ',"$black on_$bgcwhite");
	print colored('0',"$ccrapscolor0 on_$buff0");
	$buff0 = '';
}

sub ccrapsblockhw11C {
	if ($ccrapsRtotalO2 == 1) {
		$buff0 = $ccrapscolor3
	} else {
		$buff0 = $ccrapscolor1;
	}
	print colored(' ',"$ccrapscolor0 on_$buff0");
	print colored('      ',"$black on_$bgcwhite");
	print colored('Y',"$ccrapscolor0 on_$buff0");
	print colored('      ',"$black on_$bgcwhite");
	print colored('X',"$ccrapscolor0 on_$buff0");
	$buff0 = '';
}

sub ccrapsblockhw12A {
	if ($ccrapsRtotalO3 == 1) {
		$buff0 = $ccrapscolor3
	} else {
		$buff0 = $ccrapscolor1;
	}
	print colored('O',"$boldwhite on_$buff0");
	print colored('      ',"$black on_$bgcwhite");
	print colored('P',"$ccrapscolor0 on_$buff0");
	print colored(' *    ',"$black on_$bgcwhite");
	print colored('1',"$ccrapscolor0 on_$buff0");
	$buff0 = '';
}

sub ccrapsblockhw12B {
	if ($ccrapsRtotalO3 == 1) {
		$buff0 = $ccrapscolor3
	} else {
		$buff0 = $ccrapscolor1;
	}
	print colored('3',"$boldwhite on_$buff0");
	print colored('  *   ',"$black on_$bgcwhite");
	print colored('A',"$ccrapscolor0 on_$buff0");
	print colored('      ',"$black on_$bgcwhite");
	print colored('6',"$ccrapscolor0 on_$buff0");
	$buff0 = '';
}

sub ccrapsblockhw12C {
	if ($ccrapsRtotalO3 == 1) {
		$buff0 = $ccrapscolor3
	} else {
		$buff0 = $ccrapscolor1;
	}
	print colored(' ',"$ccrapscolor0 on_$buff0");
	print colored('      ',"$black on_$bgcwhite");
	print colored('Y',"$ccrapscolor0 on_$buff0");
	print colored('    * ',"$black on_$bgcwhite");
	print colored('X',"$ccrapscolor0 on_$buff0");
	$buff0 = '';
}


sub ccrapsblockhw66A {
	if ($ccrapsRtotalO12 == 1) {
		$buff0 = $ccrapscolor3
	} else {
		$buff0 = $ccrapscolor1;
	}
	print colored('O',"$boldwhite on_$buff0");
	print colored(' *  * ',"$black on_$bgcwhite");
	print colored('P',"$ccrapscolor0 on_$buff0");
	print colored(' *  * ',"$black on_$bgcwhite");
	print colored('3',"$ccrapscolor0 on_$buff0");
	$buff0 = '';
}

sub ccrapsblockhw66B {
	if ($ccrapsRtotalO12 == 1) {
		$buff0 = $ccrapscolor3
	} else {
		$buff0 = $ccrapscolor1;
	}
	print colored('1',"$boldwhite on_$buff0");
	print colored(' *  * ',"$black on_$bgcwhite");
	print colored('A',"$ccrapscolor0 on_$buff0");
	print colored(' *  * ',"$black on_$bgcwhite");
	print colored('1',"$ccrapscolor0 on_$buff0");
	$buff0 = '';
}


sub ccrapsblockhw66C {
	if ($ccrapsRtotalO12 == 1) {
		$buff0 = $ccrapscolor3
	} else {
		$buff0 = $ccrapscolor1;
	}
	print colored('2',"$boldwhite on_$buff0");
	print colored(' *  * ',"$black on_$bgcwhite");
	print colored('Y',"$ccrapscolor0 on_$buff0");
	print colored(' *  * ',"$black on_$bgcwhite");
	print colored('X',"$ccrapscolor0 on_$buff0");
	$buff0 = '';
}

sub ccrapsblockhw65A {
	if ($ccrapsRtotalO11 == 1) {
		$buff0 = $ccrapscolor3
	} else {
		$buff0 = $ccrapscolor1;
	}
	print colored('O',"$boldwhite on_$buff0");
	print colored(' *  * ',"$black on_$bgcwhite");
	print colored('P',"$ccrapscolor0 on_$buff0");
	print colored(' *  * ',"$black on_$bgcwhite");
	print colored('1',"$ccrapscolor0 on_$buff0");
	$buff0 = '';
}

sub ccrapsblockhw65B {
	if ($ccrapsRtotalO11 == 1) {
		$buff0 = $ccrapscolor3
	} else {
		$buff0 = $ccrapscolor1;
	}
	print colored('1',"$boldwhite on_$buff0");
	print colored(' *  * ',"$black on_$bgcwhite");
	print colored('A',"$ccrapscolor0 on_$buff0");
	print colored('  *   ',"$black on_$bgcwhite");
	print colored('7',"$ccrapscolor0 on_$buff0");
	$buff0 = '';
}

sub ccrapsblockhw65C {
	if ($ccrapsRtotalO11 == 1) {
		$buff0 = $ccrapscolor3
	} else {
		$buff0 = $ccrapscolor1;
	}
	print colored('1',"$boldwhite on_$buff0");
	print colored(' *  * ',"$black on_$bgcwhite");
	print colored('Y',"$ccrapscolor0 on_$buff0");
	print colored(' *  * ',"$black on_$bgcwhite");
	print colored('X',"$ccrapscolor0 on_$buff0");
	$buff0 = '';
}

sub ccrapsblockBIG68A {
	if ($ccrapsRtotalBIG6 == 1) {
		$buff0 = $ccrapscolor3
	} else {
		$buff0 = $ccrapscolor1;
	}
	print colored('B',"$boldwhite on_$buff0");
	print colored('  BIG         ',"$ccrapscolor0 on_$buff0");
	print colored(' / ',"$ccrapscolor0 on_$ccrapscolor1");
	$buff0 = '';
	if ($ccrapsRtotalBIG8 == 1) {
		$buff0 = $ccrapscolor3
	} else {
		$buff0 = $ccrapscolor1;
	}
	print colored('     BIG   ',"$ccrapscolor0 on_$buff0");
	print colored('B',"$boldwhite on_$buff0");
	$buff0 = '';	
}
sub ccrapsblockBIG68B {
	if ($ccrapsRtotalBIG6 == 1) {
		$buff0 = $ccrapscolor3
	} else {
		$buff0 = $ccrapscolor1;
	}
	print colored('I',"$boldwhite on_$buff0");
	print colored('   6         ',"$ccrapscolor0 on_$buff0");
	print colored(' / ',"$ccrapscolor0 on_$ccrapscolor1");
	$buff0 = '';
	if ($ccrapsRtotalBIG8 == 1) {
		$buff0 = $ccrapscolor3
	} else {
		$buff0 = $ccrapscolor1;
	}
	print colored('       8    ',"$ccrapscolor0 on_$buff0");
	print colored('I',"$boldwhite on_$buff0");
	$buff0 = '';
}

sub ccrapsblockBIG68C {
	if ($ccrapsRtotalBIG6 == 1) {
		$buff0 = $ccrapscolor3
	} else {
		$buff0 = $ccrapscolor1;
	}
	print colored('G',"$boldwhite on_$buff0");
	print colored('            ',"$ccrapscolor0 on_$buff0");
	print colored(' / ',"$ccrapscolor0 on_$ccrapscolor1");
	$buff0 = '';
	if ($ccrapsRtotalBIG8 == 1) {
		$buff0 = $ccrapscolor3
	} else {
		$buff0 = $ccrapscolor1;
	}
	print colored('             ',"$ccrapscolor0 on_$buff0");
	print colored('G',"$boldwhite on_$buff0");
	$buff0 = '';
}

sub ccrapsblockBIG68D {
	if ($ccrapsRtotalBIG6 == 1) {
		$buff0 = $ccrapscolor3
	} else {
		$buff0 = $ccrapscolor1;
	}
	print colored('6',"$boldwhite on_$buff0");
	print colored('  PAYS 2X  ',"$ccrapscolor0 on_$buff0");
	print colored(' / ',"$ccrapscolor0 on_$ccrapscolor1");
	$buff0 = '';
	if ($ccrapsRtotalBIG8 == 1) {
		$buff0 = $ccrapscolor3
	} else {
		$buff0 = $ccrapscolor1;
	}
	print colored('     PAYS 2X  ',"$ccrapscolor0 on_$buff0");
	print colored('8',"$boldwhite on_$buff0");
	$buff0 = '';
}

sub ccrapsblockANYC7 {
	if ($ccrapsRtotalAC == 1) {
		$buff0 = $ccrapscolor3
	} else {
		$buff0 = $ccrapscolor1;
	}
	print colored('AC',"$boldwhite on_$buff0");
	print colored('  AC PAYS 8X ',"$ccrapscolor0 on_$buff0");
	$buff0 = '';
	print colored('|',"$ccrapscolor0 on_$ccrapscolor1");
	if ($ccrapsRtotalA7 == 1) {
		$buff0 = $ccrapscolor3
	} else {
		$buff0 = $ccrapscolor1;
	}
	print colored(' A7 PAYS 5X  ',"$ccrapscolor0 on_$buff0");
	print colored('A7',"$boldwhite on_$buff0");
	$buff0 = '';
	
	
}

sub ccrapsblockPLbA {
	if ($ccrapsRtotalPL == 1) {
		$buff0 = $ccrapscolor3
	} else {
		$buff0 = $ccrapscolor1;
	}
	print colored('P',"$boldwhite on_$buff0");
	print colored('        PASS LINE BET         ',"$ccrapscolor0 on_$buff0");
	$buff0 = '';
}

sub ccrapsblockPLbB {
	if ($ccrapsRtotalPL == 1) {
		$buff0 = $ccrapscolor3
	} else {
		$buff0 = $ccrapscolor1;
	}
	print colored('L',"$boldwhite on_$buff0");
	print colored('           PAYS 2X            ',"$ccrapscolor0 on_$buff0");
	$buff0 = '';
}

sub ccrapsblockDPLbA {
	if ($ccrapsRtotalDPL == 1) {
		$buff0 = $ccrapscolor3
	} else {
		$buff0 = $ccrapscolor1;
	}
	print colored('D',"$boldwhite on_$buff0");
	print colored('     DON\'T PASS LINE BET      ',"$ccrapscolor0 on_$buff0");
	$buff0 = '';
}

sub ccrapsblockDPLbB {
	if ($ccrapsRtotalDPL == 1) {
		$buff0 = $ccrapscolor3
	} else {
		$buff0 = $ccrapscolor1;
	}
	print colored('P',"$boldwhite on_$buff0");
	print colored('                              ',"$ccrapscolor0 on_$buff0");
	$buff0 = '';
}

sub ccrapsblockDPLbC {
	if ($ccrapsRtotalDPL == 1) {
		$buff0 = $ccrapscolor3
	} else {
		$buff0 = $ccrapscolor1;
	}
	print colored('L',"$boldwhite on_$buff0");
	print colored('           PAYS 2X            ',"$ccrapscolor0 on_$buff0");
	$buff0 = '';
}

sub ccrapsblockFIbA {
	if ($ccrapsRtotalFI == 1) {
		$buff0 = $ccrapscolor3
	} else {
		$buff0 = $ccrapscolor1;
	}
	print colored('F',"$boldwhite on_$buff0");
	print colored('  FIELD BET   2 OR 12 PAYS 3X',"$ccrapscolor0 on_$buff0");
	$buff0 = '';
}

sub ccrapsblockFIbB {
	if ($ccrapsRtotalFI == 1) {
		$buff0 = $ccrapscolor3
	} else {
		$buff0 = $ccrapscolor1;
	}
	print colored('I',"$boldwhite on_$buff0");
	print colored(' 3  4  9  10  OR  11  PAYS 2X',"$ccrapscolor0 on_$buff0");
	$buff0 = '';
}

sub ccrapsblockend0 {
	print colored('>',"$ccrapscolor0 on_$ccrapscolor1");
}

sub ccrapsblockend1 {
	print colored('<',"$ccrapscolor0 on_$ccrapscolor1");
}

sub ccrapsblock0 {
	print colored('|',"$ccrapscolor0 on_$ccrapscolor1");
}

sub ccrapsblock1 {
	print colored(' ',"$ccrapscolor0 on_$ccrapscolor1");
}

sub ccrapsblock2 {
	print colored('                              ',"$ccrapscolor0 on_$ccrapscolor1");
}

sub ccrapsblock3 {
	print colored('           ',"$ccrapscolor0 on_$ccrapscolor1");
}

sub ccrapsblock4 {
	print colored('  ',"$ccrapscolor0 on_$ccrapscolor1");
}

sub ccrapsblock5 {
	print colored('-',"$ccrapscolor0 on_$ccrapscolor1");
}

sub ccrapsblock6 {
	print colored(' BET ',"$ccrapscolor0 on_$ccrapscolor1");
}

sub ccrapsblock7 {
	print colored('  FUNDS ',"$ccrapscolor0 on_$ccrapscolor1");
}

sub ccrapsblock8 {
	print colored('  WINNINGS ',"$ccrapscolor0 on_$ccrapscolor1");
}

sub ccrapsblock9 {
	print colored('  POINT ',"$ccrapscolor0 on_$ccrapscolor1");
}

sub ccrapsblock10 {
	print colored(' TOTAL ',"$ccrapscolor0 on_$ccrapscolor1");
}


sub ccrapsswitch1 {
	$ccrapsnumber = $ccrapsdrand1;
}

sub ccrapsswitch2 {
	$ccrapsnumber = $ccrapsdrand2;
}

sub ccrapsthrowdice {
	$ccrapsdrand1 = ((int(rand(6))) + 1);
	$ccrapsdrand2 = ((int(rand(6))) + 1);
}

sub ccrapsdie0 { print colored('             ',"$ccrapscolorD0 on_$ccrapscolorD1"); }
sub ccrapsdie1 { print colored('     (O)     ',"$ccrapscolorD0 on_$ccrapscolorD1"); }
sub ccrapsdie2 { print colored(' (O)         ',"$ccrapscolorD0 on_$ccrapscolorD1"); }
sub ccrapsdie3 { print colored('         (O) ',"$ccrapscolorD0 on_$ccrapscolorD1"); }
sub ccrapsdie4 { print colored(' (O)     (O) ',"$ccrapscolorD0 on_$ccrapscolorD1"); }

sub ccrapsprintD0 {
		ccrapsdie0();
}

sub ccrapsprintD1 {
	if (($ccrapsnumber == 2) or ($ccrapsnumber == 3))  {
		ccrapsdie2();
	} elsif (($ccrapsnumber == 4) or ($ccrapsnumber == 5) or ($ccrapsnumber == 6))  {
		ccrapsdie4();	
	} else {
		ccrapsdie0();
	}
}

sub ccrapsprintD2 {
	if (($ccrapsnumber == 1) or ($ccrapsnumber == 3) or ($ccrapsnumber == 5))  {
		ccrapsdie1();
	} elsif ($ccrapsnumber == 6)  {
		ccrapsdie4();	
	} else {
		ccrapsdie0();
	}
}

sub ccrapsprintD3 {
	if (($ccrapsnumber == 2) or ($ccrapsnumber == 3))  {
		ccrapsdie3();
	} elsif (($ccrapsnumber == 4) or ($ccrapsnumber == 5) or ($ccrapsnumber == 6))  {
		ccrapsdie4();	
	} else {
		ccrapsdie0();
	}
}

sub ccrapsmainprint {
print colored('/------------------------------------------------------------------------------\\',"$ccrapscolor0 on_$ccrapscolor1"); print"\n";
ccrapsblockend0(); ccrapsblock6(); ccrapsdbet(); ccrapsblock8(); ccrapsdwinnings(); ccrapsblock7(); ccrapsdmoney(); ccrapsblock9(); ccrapsdpoint(); ccrapsblock10(); ccrapsdtotal(); ccrapsblock1(); ccrapsblockend1(); print"\n";
print colored('>                                                                              <',"$ccrapscolor0 on_$ccrapscolor1"); print"\n";

ccrapsblockend0(); ccrapsblockscroll1(); ccrapsblockend1(); print"\n";
ccrapsblockend0(); ccrapsblockscroll2(); ccrapsblockend1(); print"\n";
ccrapsblockend0(); ccrapsblockscroll3(); ccrapsblockend1(); print"\n";
ccrapsblockend0(); ccrapsblockscroll4(); ccrapsblockend1(); print"\n";
ccrapsblockend0(); ccrapsblockscroll5(); ccrapsblockend1(); print"\n";
ccrapsblockend0(); ccrapsblockscroll6(); ccrapsblockend1(); print"\n";
ccrapsblockend0(); ccrapsblockscroll7(); ccrapsblockend1(); print"\n";

print colored('>                                                                              <',"$ccrapscolor0 on_$ccrapscolor1"); print"\n";
print colored('>               .--------------------------------------------------------------<',"$ccrapscolor0 on_$ccrapscolor1"); print"\n";

ccrapsblockend0(); ccrapsblockhw0(); ccrapsblock0(); ccrapsblockANYC7(); ccrapsblock0(); ccrapsblockFIbA(); ccrapsblockend1(); print"\n";
ccrapsblockend0(); ccrapsblockhard10A(); ccrapsblock0(); ccrapsblockhw0(); ccrapsblock5(); ccrapsblockhw0(); ccrapsblock0(); ccrapsblockFIbB(); ccrapsblockend1(); print"\n";
ccrapsblockend0(); ccrapsblockhard10B(); ccrapsblock0(); ccrapsblockDPLbA(); ccrapsblock0(); print colored('------------------------------',"$ccrapscolor0 on_$ccrapscolor1"); ccrapsblockend1(); print"\n";
ccrapsblockend0(); ccrapsblockhard10C(); ccrapsblock0(); ccrapsblockDPLbB(); ccrapsblock0(); ccrapsblockBIG68A(); ccrapsblockend1(); print"\n";
ccrapsblockend0(); ccrapsblockhw0(); ccrapsblock0(); ccrapsblockDPLbC(); ccrapsblock0(); ccrapsblockBIG68B(); ccrapsblockend1(); print"\n";
ccrapsblockend0(); ccrapsblockhard6A(); ccrapsblock0(); ccrapsblockhw0(); ccrapsblock5(); ccrapsblockhw0(); ccrapsblock0(); ccrapsblockBIG68C(); ccrapsblockend1(); print"\n";
ccrapsblockend0(); ccrapsblockhard6B(); ccrapsblock0(); ccrapsblockPLbA(); ccrapsblock0(); ccrapsblockBIG68D(); ccrapsblockend1(); print"\n";
ccrapsblockend0(); ccrapsblockhard6C(); ccrapsblock0(); ccrapsblockPLbB(); ccrapsblock0(); print colored('------------------------------',"$ccrapscolor0 on_$ccrapscolor1"); ccrapsblockend1(); print"\n";
ccrapsblockend0(); ccrapsblockhw0(); ccrapsblock0(); ccrapsblockhw0(); ccrapsblock5(); ccrapsblockhw0(); ccrapsblock0(); ccrapsblock2(); ccrapsblockend1(); print"\n";
ccrapsblockend0(); ccrapsblockhard8A(); ccrapsblock0(); ccrapsblockhw12A(); ccrapsblock0(); ccrapsblockhw66A(); ccrapsblock0(); ccrapsblock1(); ccrapsprintD0(); ccrapsblock4(); ccrapsprintD0(); ccrapsblock1(); ccrapsblockend1(); print"\n";
ccrapsblockend0(); ccrapsblockhard8B(); ccrapsblock0(); ccrapsblockhw12B(); ccrapsblock0(); ccrapsblockhw66B(); ccrapsblock0(); ccrapsblock1(); ccrapsswitch1(); ccrapsprintD1(); ccrapsblock4(); ccrapsswitch2(); ccrapsprintD1(); ccrapsblock1(); ccrapsblockend1(); print"\n";
ccrapsblockend0(); ccrapsblockhard8C(); ccrapsblock0(); ccrapsblockhw12C(); ccrapsblock0(); ccrapsblockhw66C(); ccrapsblock0(); ccrapsblock1(); ccrapsprintD0(); ccrapsblock4(); ccrapsprintD0(); ccrapsblock1(); ccrapsblockend1(); print"\n";
ccrapsblockend0(); ccrapsblockhw0(); ccrapsblock0(); ccrapsblockhw0(); ccrapsblock0(); ccrapsblockhw0(); ccrapsblock0(); ccrapsblock1(); ccrapsswitch1(); ccrapsprintD2(); ccrapsblock4(); ccrapsswitch2(); ccrapsprintD2(); ccrapsblock1(); ccrapsblockend1(); print"\n";
ccrapsblockend0(); ccrapsblockhard4A(); ccrapsblock0();ccrapsblockhw11A(); ccrapsblock0(); ccrapsblockhw65A(); ccrapsblock0(); ccrapsblock1(); ccrapsprintD0(); ccrapsblock4(); ccrapsprintD0(); ccrapsblock1(); ccrapsblockend1(); print"\n";
ccrapsblockend0(); ccrapsblockhard4B(); ccrapsblock0();ccrapsblockhw11B(); ccrapsblock0(); ccrapsblockhw65B(); ccrapsblock0(); ccrapsblock1(); ccrapsswitch1(); ccrapsprintD3(); ccrapsblock4(); ccrapsswitch2(); ccrapsprintD3(); ccrapsblock1(); ccrapsblockend1(); print"\n";
ccrapsblockend0(); ccrapsblockhard4C(); ccrapsblock0();ccrapsblockhw11C(); ccrapsblock0(); ccrapsblockhw65C(); ccrapsblock0(); ccrapsblock1(); ccrapsprintD0(); ccrapsblock4(); ccrapsprintD0(); ccrapsblock1(); ccrapsblockend1(); print"\n";
print colored('\\_______________|_______________|_______________|______________________________/',"$ccrapscolor0 on_$ccrapscolor1"); print"\n";
}
################################################################################################################################
sub bankmachine {
bankblanktitle();
bankblanktop();
bankblankyellow();

print colored('$',"$boldwhite on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('  Welcome to the General Public Bank, Here are your                         ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldwhite on_$bgcblack"); print"\n";

print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('  Banking Options:                                                          ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";

print colored('$',"$boldgreen on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('  1) Set Value of Slotmachine Tokens                                        ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldgreen on_$bgcblack"); print"\n";

print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('  2) Financial Report                                                       ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";

print colored('$',"$boldwhite on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('  3) Savings Account Deposit                                                ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldwhite on_$bgcblack"); print"\n";

print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('  4) Savings Account Withdrawal                                             ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";

print colored('$',"$boldgreen on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('  5) Stock Investment                                                       ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldgreen on_$bgcblack"); print"\n";

bankblankyellow();

if ($allowsave == 1) {
	print colored('$',"$boldwhite on_$bgcblack");
	print colored('|',"$boldwhite on_$bgcwhite");
	print colored('  6) Cashout                                                                ',"$white on_$bgcblack");
	print colored('|',"$boldwhite on_$bgcwhite");
	print colored('$',"$boldwhite on_$bgcblack"); print"\n";

	print colored('$',"$boldyellow on_$bgcblack");
	print colored('|',"$boldwhite on_$bgcwhite");
	if ($loadedsavefile == 1) {
	print colored('  7) Cashin                                                                 ',"$boldblack on_$bgcblack");
	} else {
	print colored('  7) Cashin                                                                 ',"$white on_$bgcblack");
	}
	print colored('|',"$boldwhite on_$bgcwhite");
	print colored('$',"$boldyellow on_$bgcblack"); print"\n";
} else {
	bankblankwhite();
	bankblankyellow();
}

bankblankgreen();
bankblankyellow();
bankblankwhite();
bankblankyellow();
bankblankgreen();
bankblankyellow();
bankblankwhite();
bankblankyellow();
bankblankgreen();
bankblankyellow();
bankblankwhite();
bankblankyellow();

print colored('$',"$boldgreen on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");                                             #'
print colored('                    Press "C" To Return to Casino Menu                      ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldgreen on_$bgcblack"); print"\n";

bankblankyellow();

bankblankbottom();

bankblanktitle();
bankstartinfo();
}

sub bankerror {
bankblanktitle();
bankblanktop();
bankblankyellow();

print colored('$',"$boldwhite on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('  ERROR                                                                     ',"$red on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldwhite on_$bgcblack"); print"\n";

print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored("  $buff0  ","$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";

print colored('$',"$boldgreen on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored("  $buff2  ","$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldgreen on_$bgcblack"); print"\n";

bankblankyellow();
bankblankwhite();
bankblankyellow();
bankblankgreen();
bankblankyellow();
bankblankwhite();
bankblankyellow();
bankblankgreen();
bankblankyellow();
bankblankwhite();
bankblankyellow();
bankblankgreen();
bankblankyellow();
bankblankwhite();
bankblankyellow();
bankblankgreen();
bankblankyellow();
bankblankwhite();
bankblankyellow();
bankblankgreen();
bankblankyellow();

bankblankbottom();

bankblanktitle();
$buff0 = <STDIN>;
$buff0 = '';
}

sub bankinfo {
bankblanktitle();
bankblanktop();
bankblankyellow();

print colored('$',"$boldwhite on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('  INFO                                                                      ',"$green on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldwhite on_$bgcblack"); print"\n";

print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored("  $buff0  ","$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";

print colored('$',"$boldgreen on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored("  $buff2  ","$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldgreen on_$bgcblack"); print"\n";

bankblankyellow();
bankblankwhite();
bankblankyellow();
bankblankgreen();
bankblankyellow();
bankblankwhite();
bankblankyellow();
bankblankgreen();
bankblankyellow();
bankblankwhite();
bankblankyellow();
bankblankgreen();
bankblankyellow();
bankblankwhite();
bankblankyellow();
bankblankgreen();
bankblankyellow();
bankblankwhite();
bankblankyellow();
bankblankgreen();
bankblankyellow();

bankblankbottom();

bankblanktitle();
$buff0 = <STDIN>;
$buff0 = '';
}

sub bankstockedit {
bankblanktitle();
bankblanktop();
bankblankyellow();

print colored('$',"$boldwhite on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('  Please select which market fund you would like to invest in/divest from.  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldwhite on_$bgcblack"); print"\n";

print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('  Name of Fund:           Current Share Price:   Number of Shares You Own:  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";

$buff0 = $fundretailsharevalue;
bankcropsinglestat();
print colored('$',"$boldgreen on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('  1) Retail               ',"$white on_$bgcblack");                      
print colored("$buff0","$boldgreen on_$bgcblack");
$buff0 = '';
$buff1 = '';
print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldgreen on_$bgcblack"); print"\n";

$buff0 = $fundretailshares;
bankcropsinglestatbk();
print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('                          ',"$white on_$bgcblack");                      
print colored("$buff0","$boldwhite on_$bgcblack");
$buff0 = '';
$buff1 = '';
print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";



$buff0 = $fundindustrysharevalue;
bankcropsinglestat();
print colored('$',"$boldwhite on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('  2) Industrial           ',"$white on_$bgcblack");                      
print colored("$buff0","$boldgreen on_$bgcblack");
$buff0 = '';
$buff1 = '';
print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldwhite on_$bgcblack"); print"\n";

$buff0 = $fundindustryshares;
bankcropsinglestatbk();
print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('                          ',"$white on_$bgcblack");                      
print colored("$buff0","$boldwhite on_$bgcblack");
$buff0 = '';
$buff1 = '';
print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";



$buff0 = $fundtechsharevalue;
bankcropsinglestat();
print colored('$',"$boldgreen on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('  3) Technology           ',"$white on_$bgcblack");                      
print colored("$buff0","$boldgreen on_$bgcblack");
$buff0 = '';
$buff1 = '';
print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldgreen on_$bgcblack"); print"\n";

$buff0 = $fundtechshares;
bankcropsinglestatbk();
print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('                          ',"$white on_$bgcblack");                      
print colored("$buff0","$boldwhite on_$bgcblack");
$buff0 = '';
$buff1 = '';
print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";



$buff0 = $fundenergysharevalue;
bankcropsinglestat();
print colored('$',"$boldwhite on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('  4) Energy               ',"$white on_$bgcblack");                      
print colored("$buff0","$boldgreen on_$bgcblack");
$buff0 = '';
$buff1 = '';
print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldwhite on_$bgcblack"); print"\n";

$buff0 = $fundenergyshares;
bankcropsinglestatbk();
print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('                          ',"$white on_$bgcblack");                      
print colored("$buff0","$boldwhite on_$bgcblack");
$buff0 = '';
$buff1 = '';
print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";





$buff0 = $fundtextilesharevalue;
bankcropsinglestat();
print colored('$',"$boldgreen on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('  5) Textile              ',"$white on_$bgcblack");                      
print colored("$buff0","$boldgreen on_$bgcblack");
$buff0 = '';
$buff1 = '';
print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldgreen on_$bgcblack"); print"\n";

$buff0 = $fundtextileshares;
bankcropsinglestatbk();
print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('                          ',"$white on_$bgcblack");                      
print colored("$buff0","$boldwhite on_$bgcblack");
$buff0 = '';
$buff1 = '';
print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";



$buff0 = $fundinvestmentsharevalue;
bankcropsinglestat();
print colored('$',"$boldwhite on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('  6) Investment House     ',"$white on_$bgcblack");                      
print colored("$buff0","$boldgreen on_$bgcblack");
$buff0 = '';
$buff1 = '';
print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldwhite on_$bgcblack"); print"\n";

$buff0 = $fundinvestmentshares;
bankcropsinglestatbk();
print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('                          ',"$white on_$bgcblack");                      
print colored("$buff0","$boldwhite on_$bgcblack");
$buff0 = '';
$buff1 = '';
print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";





$buff0 = $fundlendingsharevalue;
bankcropsinglestat();
print colored('$',"$boldgreen on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('  7) Lending              ',"$white on_$bgcblack");                      
print colored("$buff0","$boldgreen on_$bgcblack");
$buff0 = '';
$buff1 = '';
print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldgreen on_$bgcblack"); print"\n";

$buff0 = $fundlendingshares;
bankcropsinglestatbk();
print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('                          ',"$white on_$bgcblack");                      
print colored("$buff0","$boldwhite on_$bgcblack");
$buff0 = '';
$buff1 = '';
print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";



$buff0 = $fundconstructionsharevalue;
bankcropsinglestat();
print colored('$',"$boldwhite on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('  8) Construction         ',"$white on_$bgcblack");                      
print colored("$buff0","$boldgreen on_$bgcblack");
$buff0 = '';
$buff1 = '';
print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldwhite on_$bgcblack"); print"\n";

$buff0 = $fundconstructionshares;
bankcropsinglestatbk();
print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('                          ',"$white on_$bgcblack");                      
print colored("$buff0","$boldwhite on_$bgcblack");
$buff0 = '';
$buff1 = '';
print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";



$buff0 = $fundminingsharevalue;
bankcropsinglestat();
print colored('$',"$boldgreen on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('  9) Mining               ',"$white on_$bgcblack");                      
print colored("$buff0","$boldgreen on_$bgcblack");
$buff0 = '';
$buff1 = '';
print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldgreen on_$bgcblack"); print"\n";

$buff0 = $fundminingshares;
bankcropsinglestatbk();
print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('                          ',"$white on_$bgcblack");                      
print colored("$buff0","$boldwhite on_$bgcblack");
$buff0 = '';
$buff1 = '';
print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";


$buff0 = $fundindexsharevalue;
bankcropsinglestat();
print colored('$',"$boldwhite on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('  10) Index               ',"$white on_$bgcblack");                      
print colored("$buff0","$boldgreen on_$bgcblack");
$buff0 = '';
$buff1 = '';
print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldwhite on_$bgcblack"); print"\n";

$buff0 = $fundindexshares;
bankcropsinglestatbk();
print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('                          ',"$white on_$bgcblack");                      
print colored("$buff0","$boldwhite on_$bgcblack");
$buff0 = '';
$buff1 = '';
print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";


print colored('$',"$boldgreen on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");                                             #'
print colored('                   Press "C" To Return to Previous Screen                   ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldgreen on_$bgcblack"); print"\n";

bankblankyellow();

bankblankbottom();

bankblanktitle();

	$buff0 = '';
	$buff0 = <STDIN>;
	chomp($buff0);
	
	if ($buff0 ne '') {
		if (($buff0 eq 'c') or ($buff0 eq 'C')) {
			newlines();
			return;
		} elsif (($buff0 >= 1) and ($buff0 <= 10)) { #If one of the market funds were selected
			$bankstocktoedit = $buff0; #What stock we're editing;
			newlines();
			bankfundedit();
		}
	}
	newlines();
	bankstockedit();
}


sub bankfundedit {
bankblanktitle();
bankblanktop();
bankblankyellow();

print colored('$',"$boldwhite on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('  PORTFOLIO MANAGMENT                                                       ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldwhite on_$bgcblack"); print"\n";

bankstockinfo();

bankblankwhite();

print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");                                             #'
if (($bankstocktoedit == 10) and ($fundindexshares >= 1)) {
print colored('  1) Buy Shares      3) Info                                                ',"$white on_$bgcblack");
#You get the extra info if you are invested in the index fund
} else {
print colored('  1) Buy Shares                                                             ',"$white on_$bgcblack");
}
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";


print colored('$',"$boldgreen on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");                                             #'
print colored('  2) Sell Shares                                                            ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldgreen on_$bgcblack"); print"\n";

bankblankyellow();
bankblankbottom();
bankblanktitle();

	$buff0 = '';
	$buff0 = <STDIN>;
	chomp($buff0);
	#$buff0 =~ s/\D//g; #Remove non digits
	#$buff0 =~ s/^0*//; #Remove leading zeroes
	
	if ($buff0 ne '') {
		if (($buff0 == 1) or ($buff0 eq 'b') or ($buff0 eq 'B')) {
			newlines();
			bankstockbuy(); #$bankstocktoedit is unchanged so it will be picked up next
		} elsif (($buff0 == 2) or ($buff0 eq 's') or ($buff0 eq 'S')) {
			newlines();
			bankstocksell(); #$bankstocktoedit is unchanged so it will be picked up next
		} elsif (
			(($bankstocktoedit == 10) and ($fundindexshares >= 1))
			and 
			(($buff0 == 3) or ($buff0 eq 'i') or ($buff0 eq 'I'))
			)
			{
			$bankfndmorinfo = 1;
			newlines();
			bankfundedit();
			$bankfndmorinfo = 0;
		}
	}
	newlines();
	##We just return to bankfundedit(); if nothing was done.
}

sub bankstockbuy {
bankblanktitle();
bankblanktop();
bankblankyellow();

print colored('$',"$boldwhite on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('  PORTFOLIO MANAGMENT                                           Buy Shares  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldwhite on_$bgcblack"); print"\n";

bankstockinfo();

bankblankwhite();

print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");                                             #'
print colored('                                                                            ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";

print colored('$',"$boldgreen on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");                                             #'
print colored('  Enter the amount of shares you wish to buy.                               ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldgreen on_$bgcblack"); print"\n";

bankblankyellow();
bankblankbottom();
bankblanktitle();
print"enter share amount [$bankstkbuy]: ";

	$buff0 = '';
	$buff0 = <STDIN>;
	chomp($buff0);
	$buff0 =~ s/\D//g; #Remove non digits
	$buff0 =~ s/^0*//; #Remove leading zeroes
	
	$bankstkerr = 0; #No error yet.
	
	$bankstkamnt = 0; #Amount of shares owned. Zero untill transaction
	$bankstkcst = 0; #Cost of stocks + Commisson + Flat Fee. Zero untill transaction
	$bankstkvalue = 0; #Zero untill transaction.
	
	if ($buff0 ne '') {
		if (0 < $buff0) {
			##Here we transfer the info into the generic variables
			if ($bankstocktoedit == 1) {
				$bankstkvalue = $fundretailsharevalue;
				$bankstkamnt = $fundretailshares;
			} elsif ($bankstocktoedit == 2) {
				$bankstkvalue =  $fundindustrysharevalue;
				$bankstkamnt = $fundindustryshares;
			} elsif ($bankstocktoedit == 3) {
				$bankstkvalue =  $fundtechsharevalue;
				$bankstkamnt = $fundtechshares;
			} elsif ($bankstocktoedit == 4) {
				$bankstkvalue = $fundenergysharevalue;
				$bankstkamnt = $fundenergyshares;
			} elsif ($bankstocktoedit == 5) {
				$bankstkvalue = $fundtextilesharevalue;
				$bankstkamnt = $fundtextileshares;
			} elsif ($bankstocktoedit == 6) {
				$bankstkvalue = $fundinvestmentsharevalue;
				$bankstkamnt = $fundinvestmentshares;
			} elsif ($bankstocktoedit == 7) {
				$bankstkvalue = $fundlendingsharevalue;
				$bankstkamnt = $fundlendingshares;
			} elsif ($bankstocktoedit == 8) {
				$bankstkvalue = $fundconstructionsharevalue;
				$bankstkamnt = $fundconstructionshares;
			} elsif ($bankstocktoedit == 9) {
				$bankstkvalue = $fundminingsharevalue;
				$bankstkamnt = $fundminingshares;
			} elsif ($bankstocktoedit == 10) {
				$bankstkvalue = $fundindexsharevalue;
				$bankstkamnt = $fundindexshares;
			} else {
				$bankstkerr = 1;
			}
			##Ok now we operate, later we will transfer back
		
			$bankstkbuy = $buff0;
			$bankstkcst = (($bankstkbuy * $bankstkvalue) 
					+ ceil(($stocktcom * ($bankstkbuy * $bankstkvalue))) 
					+ ($stocktcst));
					#Cost of stocks + Commisson + Flat Fee
			$bankstkcst = ceil($bankstkcst);
					#Round cost up to nearest whole number.
			if ($bankstkerr == 1) {
				#Do Nothing but complain
				$buff0 = "Sorry, Fund Number: $bankstocktoedit";
				$buff2 = 'is currently not a valid entry.';
				bankcropmessage0();
				bankcropmessage2();
				newlines();
				bankerror();
				$buff0 = '';
				$buff1 = '';
				$buff2 = '';
				$bankstkerr = 0;
			} elsif ($money >= $bankstkcst) {
				##The transaction
				$money = $money - $bankstkcst; #Payment.
				$bankstkamnt = $bankstkamnt + $bankstkbuy; #Stock amount is now what you asked for.
				##Tracking info
				#Lets not track this
				
				if ($bankstocktoedit == 1) {
					$fundretailshares = $bankstkamnt;
				} elsif ($bankstocktoedit == 2) {
					$fundindustryshares = $bankstkamnt;
				} elsif ($bankstocktoedit == 3) {
					$fundtechshares = $bankstkamnt;
				} elsif ($bankstocktoedit == 4) {
					$fundenergyshares = $bankstkamnt;
				} elsif ($bankstocktoedit == 5) {
					$fundtextileshares = $bankstkamnt;
				} elsif ($bankstocktoedit == 6) {
					$fundinvestmentshares = $bankstkamnt;
				} elsif ($bankstocktoedit == 7) {
					$fundlendingshares = $bankstkamnt;
				} elsif ($bankstocktoedit == 8) {
					$fundconstructionshares = $bankstkamnt;
				} elsif ($bankstocktoedit == 9) {
					$fundminingshares = $bankstkamnt;
				} elsif ($bankstocktoedit == 10) {
					$fundindexshares = $bankstkamnt;				
				} else {
					#Give Money Back if transaction impossible.
					$money = $money + $bankstkcst; #Restitution.
				}
				
				$buff0 = "Purchase of $bankstkbuy shares cost: $bankstkcst";
				$buff3 = ($bankstkbuy * $bankstkvalue);
				$buff4 = ceil(($stocktcom * ($bankstkbuy * $bankstkvalue)));
				$buff2 = "Total Stock Cost: $buff3".
				" Plus Commission: $buff4".
				" Plus Fee: $stocktcst";
				bankcropmessage0();
				bankcropmessage2();
				newlines();
				bankinfo();
				$buff0 = '';
				$buff1 = '';
				$buff2 = '';
				$buff3 = '';
				$buff4 = '';
			} else {
			 #Do Nothing but complain
			 $buff0 = "Attempted purchase: $bankstkcst";
			 $buff2 = 'is greater than current cash funds.';
			 bankcropmessage0();
			 bankcropmessage2();
			 newlines();
			 bankerror();
			 $buff0 = '';
			 $buff1 = '';
			 $buff2 = '';
			}
		} else {
		 #Do Nothing but complain 
		 #This won't occur due to the stripping out of non digit chars though
		 #Nice to have an error if it does somehow.
		 $buff0 = "Purchase cannot be zero or negative.";
		 $buff2 = '';
		 bankcropmessage0();
		 bankcropmessage2();
		 newlines();
		 bankerror();
		 $buff0 = '';
		 $buff1 = '';
		 $buff2 = '';
		}
	} else {
	 #Do Nothing
	}
	$buff0 = '';
	$bankstkbuy = 0;
	$bankstkamnt = 0; 
	$bankstkcst = 0;
	$bankstkvalue = 0;

newlines();
bankfundedit();
}

sub bankstocksell {
bankblanktitle();
bankblanktop();
bankblankyellow();

print colored('$',"$boldwhite on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('  PORTFOLIO MANAGMENT                                          Sell Shares  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldwhite on_$bgcblack"); print"\n";

bankstockinfo();

bankblankwhite();

print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");                                             #'
print colored('                                                                            ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";

print colored('$',"$boldgreen on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");                                             #'
print colored('  Enter the amount of shares you wish to sell.                              ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldgreen on_$bgcblack"); print"\n";

bankblankyellow();
bankblankbottom();
bankblanktitle();
print"enter share amount [$bankstksell]: ";

	$buff0 = '';
	$buff0 = <STDIN>;
	chomp($buff0);
	$buff0 =~ s/\D//g; #Remove non digits
	$buff0 =~ s/^0*//; #Remove leading zeroes
	
	$bankstkerr = 0; #No error yet.
	
	$bankstkamnt = 0; #Amount of shares owned. Zero untill transaction.
	$bankstkcst = 0; #Sale of stocks - Tax - Flat fee. Zero untill transaction.
	$bankstkvalue = 0; #Zero untill transaction.
	
	if ($buff0 ne '') {
		if (0 < $buff0) {
			##Here we transfer the info into the generic variables
			if ($bankstocktoedit == 1) {
				$bankstkvalue = $fundretailsharevalue;
				$bankstkamnt = $fundretailshares;
			} elsif ($bankstocktoedit == 2) {
				$bankstkvalue =  $fundindustrysharevalue;
				$bankstkamnt = $fundindustryshares;
			} elsif ($bankstocktoedit == 3) {
				$bankstkvalue =  $fundtechsharevalue;
				$bankstkamnt = $fundtechshares;
			} elsif ($bankstocktoedit == 4) {
				$bankstkvalue = $fundenergysharevalue;
				$bankstkamnt = $fundenergyshares;
			} elsif ($bankstocktoedit == 5) {
				$bankstkvalue = $fundtextilesharevalue;
				$bankstkamnt = $fundtextileshares;
			} elsif ($bankstocktoedit == 6) {
				$bankstkvalue = $fundinvestmentsharevalue;
				$bankstkamnt = $fundinvestmentshares;
			} elsif ($bankstocktoedit == 7) {
				$bankstkvalue = $fundlendingsharevalue;
				$bankstkamnt = $fundlendingshares;
			} elsif ($bankstocktoedit == 8) {
				$bankstkvalue = $fundconstructionsharevalue;
				$bankstkamnt = $fundconstructionshares;	
			} elsif ($bankstocktoedit == 9) {
				$bankstkvalue = $fundminingsharevalue;
				$bankstkamnt = $fundminingshares;
			} elsif ($bankstocktoedit == 10) {
				$bankstkvalue = $fundindexsharevalue;
				$bankstkamnt = $fundindexshares;		
			} else {
				$bankstkerr = 1;
			}
			##Ok now we operate, later we will transfer back
		
			$bankstksell = $buff0;
			$bankstkcst = (($bankstksell * $bankstkvalue) 
					- (ceil($stocktax * ($bankstksell * $bankstkvalue)))
					- $stocktcstsl);
					#Socialism comes to steal from you. It rounds up.
					#And then a flat fee.
			$bankstkcst = floor($bankstkcst);
					#Round money from sale down to nearest whole number.
			if (0 > $bankstkcst) {
				$bankstkcst = 0; #We won't make a sale a complete loss.
			}
			
			if ($bankstkerr == 1) {
				#Do Nothing but complain
				$buff0 = "Sorry, Fund Number: $bankstocktoedit";
				$buff2 = 'is currently not a valid entry.';
				bankcropmessage0();
				bankcropmessage2();
				newlines();
				bankerror();
				$buff0 = '';
				$buff1 = '';
				$buff2 = '';
				$bankstkerr = 0;
			} elsif ($bankstkamnt >= $bankstksell) { #Can't sell more than you have.
				##The transaction
				$money = $money + $bankstkcst; #Sale.
				$bankstkamnt = $bankstkamnt - $bankstksell; #Stock amount is less your sale.
				##Tracking info
				#Lets not track this
				
				if ($bankstocktoedit == 1) {
					$fundretailshares = $bankstkamnt;
				} elsif ($bankstocktoedit == 2) {
					$fundindustryshares = $bankstkamnt;
				} elsif ($bankstocktoedit == 3) {
					$fundtechshares = $bankstkamnt;
				} elsif ($bankstocktoedit == 4) {
					$fundenergyshares = $bankstkamnt;
				} elsif ($bankstocktoedit == 5) {
					$fundtextileshares = $bankstkamnt;
				} elsif ($bankstocktoedit == 6) {
					$fundinvestmentshares = $bankstkamnt;
				} elsif ($bankstocktoedit == 7) {
					$fundlendingshares = $bankstkamnt;
				} elsif ($bankstocktoedit == 8) {
					$fundconstructionshares = $bankstkamnt;
				} elsif ($bankstocktoedit == 9) {
					$fundminingshares = $bankstkamnt;
				} elsif ($bankstocktoedit == 10) {
					$fundindexshares = $bankstkamnt;				
				} else {
					#Give Money Back if transaction impossible.
					$money = $money + $bankstkcst; #Restitution.
				}
				
				$buff0 = "Sale of $bankstksell shares valued at: $bankstkcst";
				$buff3 = ($bankstksell * $bankstkvalue);
				$buff4 = ceil(($stocktax * ($bankstksell * $bankstkvalue)));
				$buff2 = "Total Stock Value: $buff3".
				" Minus Tax: $buff4".
				" Minus Fee: $stocktcstsl";
				bankcropmessage0();
				bankcropmessage2();
				newlines();
				bankinfo();
				$buff0 = '';
				$buff1 = '';
				$buff2 = '';
				$buff3 = '';
				$buff4 = '';
			} else {
			 #Do Nothing but complain
			 $buff0 = "Attempted sale: $bankstksell";
			 $buff2 = 'is greater than current share holdings.';
			 bankcropmessage0();
			 bankcropmessage2();
			 newlines();
			 bankerror();
			 $buff0 = '';
			 $buff1 = '';
			 $buff2 = '';
			}
		} else {
		 #Do Nothing but complain 
		 #This won't occur due to the stripping out of non digit chars though
		 #Nice to have an error if it does somehow.
		 $buff0 = "Sale ammount cannot be zero or negative.";
		 $buff2 = '';
		 bankcropmessage0();
		 bankcropmessage2();
		 newlines();
		 bankerror();
		 $buff0 = '';
		 $buff1 = '';
		 $buff2 = '';
		}
	} else {
	 #Do Nothing
	}
	$buff0 = '';
	$bankstksell = 0;
	$bankstkamnt = 0; 
	$bankstkcst = 0;
	$bankstkvalue = 0;

newlines();
bankfundedit();
}

sub bankstocktrk {
	if ($bankstocktoedit == 1) {
		$buff0 = @fundretailtracker["$buff1"];
	} elsif ($bankstocktoedit == 2) {
		$buff0 = @fundindustrytracker["$buff1"];
	} elsif ($bankstocktoedit == 3) {
		$buff0 = @fundtechtracker["$buff1"];
	} elsif ($bankstocktoedit == 4) {
		$buff0 = @fundenergytracker["$buff1"];
	} elsif ($bankstocktoedit == 5) {
		$buff0 = @fundtextiletracker["$buff1"];
	} elsif ($bankstocktoedit == 6) {
		$buff0 = @fundinvestmenttracker["$buff1"];
	} elsif ($bankstocktoedit == 7) {
		$buff0 = @fundlendingtracker["$buff1"];
	} elsif ($bankstocktoedit == 8) {
		$buff0 = @fundconstructiontracker["$buff1"];
	} elsif ($bankstocktoedit == 9) {
		$buff0 = @fundminingtracker["$buff1"];
	} elsif ($bankstocktoedit == 10) {
		$buff0 = @fundindextracker["$buff1"];			
	} else {
		$bankstocktoedit = 1;
		$bankstocksv = $fundretailtracker["$buff1"];
	}
}

sub bankstockinfo {
print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('  Name of Fund:           Current Share Price:   Number of Shares You Own:  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";

print colored('$',"$boldgreen on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 

if ($bankstocktoedit == 1) {
	$buff0 = $fundretailsharevalue;
	print colored('     Retail               ',"$white on_$bgcblack");
} elsif ($bankstocktoedit == 2) {
	$buff0 = $fundindustrysharevalue;
	print colored('     Industrial           ',"$white on_$bgcblack");                      
} elsif ($bankstocktoedit == 3) {
	$buff0 = $fundtechsharevalue;
	print colored('     Technology           ',"$white on_$bgcblack");
} elsif ($bankstocktoedit == 4) {
	$buff0 = $fundenergysharevalue;
	print colored('     Energy               ',"$white on_$bgcblack");                      
} elsif ($bankstocktoedit == 5) {
	$buff0 = $fundtextilesharevalue;
	print colored('     Textile              ',"$white on_$bgcblack");                      
} elsif ($bankstocktoedit == 6) {
	$buff0 = $fundinvestmentsharevalue;
	print colored('     Investment House     ',"$white on_$bgcblack");
} elsif ($bankstocktoedit == 7) {
	$buff0 = $fundlendingsharevalue;
	print colored('     Lending              ',"$white on_$bgcblack");
} elsif ($bankstocktoedit == 8) {
	$buff0 = $fundconstructionsharevalue;				
	print colored('     Construction         ',"$white on_$bgcblack");
} elsif ($bankstocktoedit == 9) {
	$buff0 = $fundminingsharevalue;				
	print colored('     Mining               ',"$white on_$bgcblack");
} elsif ($bankstocktoedit == 10) {
	$buff0 = $fundindexsharevalue;				
	print colored('     Index                ',"$white on_$bgcblack");
} else {
	$bankstocktoedit = 1;
	$bankstocksv = $fundretailsharevalue;
	print colored('     ERROR                ',"$white on_$bgcblack");
}
bankcropsinglestat();                 
print colored("$buff0","$boldgreen on_$bgcblack");
$buff0 = '';
$buff1 = '';
print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldgreen on_$bgcblack"); print"\n";

if ($bankstocktoedit == 1) {
	$buff0 = $fundretailshares;
} elsif ($bankstocktoedit == 2) {
	$buff0 = $fundindustryshares;
} elsif ($bankstocktoedit == 3) {
	$buff0 = $fundtechshares;
} elsif ($bankstocktoedit == 4) {
	$buff0 = $fundenergyshares;
} elsif ($bankstocktoedit == 5) {
	$buff0 = $fundtextileshares;
} elsif ($bankstocktoedit == 6) {
	$buff0 = $fundinvestmentshares;
} elsif ($bankstocktoedit == 7) {
	$buff0 = $fundlendingshares;
} elsif ($bankstocktoedit == 8) {
	$buff0 = $fundconstructionshares;
} elsif ($bankstocktoedit == 9) {
	$buff0 = $fundminingshares;
} elsif ($bankstocktoedit == 10) {
	$buff0 = $fundindexshares;			
} else {
	$bankstocktoedit = 1;
	$bankstocksv = $fundretailshares;
}
bankcropsinglestatbk();
print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('                          ',"$white on_$bgcblack");                      
print colored("$buff0","$boldwhite on_$bgcblack");
$buff0 = '';
$buff1 = '';
print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";

	if ($bankfndmorinfo == 1) {
		bankindexfndnfo();
	} else {
		bankstockhist();
	}

}

sub bankindexfndnfo {
print colored('$',"$boldwhite on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");                                            #
print colored('  Sector      Init Shares          Init Value          Current Value      ',"$white on_$bgcblack");
print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldwhite on_$bgcblack"); print"\n";

$bankfndnfovlutly = 0; #Tally for current values of Stock * Value. (Total)
###
print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('  Retail      ',"$red on_$bgcblack");
$buff0 = $fundindexretail; #Number of shares fund purchased
bankindexfndstatbk();                    
print colored("$buff0","$red on_$bgcblack");
$buff0 = '';
$buff1 = '';

$buff0 = @fundindexvalueinit[0]; #Initial Value
$buff0 = sprintf "%.3f",$buff0; #Format to 3 decimal places
bankindexfndstatbk();                   
print colored("$buff0","$red on_$bgcblack");
$buff0 = '';
$buff1 = '';

$buff0 = ($fundindexretail * $fundretailsharevalue); #Current Value
$bankfndnfovlutly = $bankfndnfovlutly + $buff0;
if ($buff0 >= @fundindexvalueinit[0]) {
	$buff2 = $boldblack;
} else {
	$buff2 = $red;
}
$buff0 = sprintf "%.3f",$buff0; #Format to 3 decimal places
bankindexfndstatbk();
print colored("$buff0","$buff2 on_$bgcblack");
$buff0 = '';
$buff1 = '';
$buff2 = '';

print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";
#####

###
print colored('$',"$boldgreen on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('  Industry    ',"$red on_$bgcblack");
$buff0 = $fundindexindustry; #Number of shares fund purchased
bankindexfndstatbk();                    
print colored("$buff0","$red on_$bgcblack");
$buff0 = '';
$buff1 = '';

$buff0 = @fundindexvalueinit[1]; #Initial Value
$buff0 = sprintf "%.3f",$buff0; #Format to 3 decimal places
bankindexfndstatbk();                   
print colored("$buff0","$red on_$bgcblack");
$buff0 = '';
$buff1 = '';

$buff0 = ($fundindexindustry * $fundindustrysharevalue); #Current Value
$bankfndnfovlutly = $bankfndnfovlutly + $buff0;
if ($buff0 >= @fundindexvalueinit[1]) {
	$buff2 = $boldblack;
} else {
	$buff2 = $red;
}
$buff0 = sprintf "%.3f",$buff0; #Format to 3 decimal places
bankindexfndstatbk();
print colored("$buff0","$buff2 on_$bgcblack");
$buff0 = '';
$buff1 = '';
$buff2 = '';

print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldgreen on_$bgcblack"); print"\n";
#####

###
print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('  Tech        ',"$red on_$bgcblack");
$buff0 = $fundindextech; #Number of shares fund purchased
bankindexfndstatbk();                    
print colored("$buff0","$red on_$bgcblack");
$buff0 = '';
$buff1 = '';

$buff0 = @fundindexvalueinit[2]; #Initial Value
$buff0 = sprintf "%.3f",$buff0; #Format to 3 decimal places
bankindexfndstatbk();                   
print colored("$buff0","$red on_$bgcblack");
$buff0 = '';
$buff1 = '';

$buff0 = ($fundindextech * $fundtechsharevalue); #Current Value
$bankfndnfovlutly = $bankfndnfovlutly + $buff0;
if ($buff0 >= @fundindexvalueinit[2]) {
	$buff2 = $boldblack;
} else {
	$buff2 = $red;
}
$buff0 = sprintf "%.3f",$buff0; #Format to 3 decimal places
bankindexfndstatbk();
print colored("$buff0","$buff2 on_$bgcblack");
$buff0 = '';
$buff1 = '';
$buff2 = '';

print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";
#####

###
print colored('$',"$boldwhite on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('  Energy      ',"$boldred on_$bgcblack");
$buff0 = $fundindexenergy; #Number of shares fund purchased
bankindexfndstatbk();                    
print colored("$buff0","$boldred on_$bgcblack");
$buff0 = '';
$buff1 = '';

$buff0 = @fundindexvalueinit[3]; #Initial Value
$buff0 = sprintf "%.3f",$buff0; #Format to 3 decimal places
bankindexfndstatbk();                   
print colored("$buff0","$boldred on_$bgcblack");
$buff0 = '';
$buff1 = '';

$buff0 = ($fundindexenergy * $fundenergysharevalue); #Current Value
$bankfndnfovlutly = $bankfndnfovlutly + $buff0;
if ($buff0 >= @fundindexvalueinit[3]) {
	$buff2 = $boldblack;
} else {
	$buff2 = $red;
}
$buff0 = sprintf "%.3f",$buff0; #Format to 3 decimal places
bankindexfndstatbk();
print colored("$buff0","$buff2 on_$bgcblack");
$buff0 = '';
$buff1 = '';
$buff2 = '';

print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldwhite on_$bgcblack"); print"\n";
#####

###
print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('  Textile     ',"$boldred on_$bgcblack");
$buff0 = $fundindextextile; #Number of shares fund purchased
bankindexfndstatbk();                    
print colored("$buff0","$boldred on_$bgcblack");
$buff0 = '';
$buff1 = '';

$buff0 = @fundindexvalueinit[4]; #Initial Value
$buff0 = sprintf "%.3f",$buff0; #Format to 3 decimal places
bankindexfndstatbk();                   
print colored("$buff0","$boldred on_$bgcblack");
$buff0 = '';
$buff1 = '';

$buff0 = ($fundindextextile * $fundtextilesharevalue); #Current Value
$bankfndnfovlutly = $bankfndnfovlutly + $buff0;
if ($buff0 >= @fundindexvalueinit[4]) {
	$buff2 = $boldblack;
} else {
	$buff2 = $red;
}
$buff0 = sprintf "%.3f",$buff0; #Format to 3 decimal places
bankindexfndstatbk();
print colored("$buff0","$buff2 on_$bgcblack");
$buff0 = '';
$buff1 = '';
$buff2 = '';

print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";
#####


###
print colored('$',"$boldgreen on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('  Investment  ',"$boldred on_$bgcblack");
$buff0 = $fundindexinvestment; #Number of shares fund purchased
bankindexfndstatbk();                    
print colored("$buff0","$boldred on_$bgcblack");
$buff0 = '';
$buff1 = '';

$buff0 = @fundindexvalueinit[5]; #Initial Value
$buff0 = sprintf "%.3f",$buff0; #Format to 3 decimal places
bankindexfndstatbk();                   
print colored("$buff0","$boldred on_$bgcblack");
$buff0 = '';
$buff1 = '';

$buff0 = ($fundindexinvestment * $fundinvestmentsharevalue); #Current Value
$bankfndnfovlutly = $bankfndnfovlutly + $buff0;
if ($buff0 >= @fundindexvalueinit[5]) {
	$buff2 = $boldblack;
} else {
	$buff2 = $red;
}
$buff0 = sprintf "%.3f",$buff0; #Format to 3 decimal places
bankindexfndstatbk();
print colored("$buff0","$buff2 on_$bgcblack");
$buff0 = '';
$buff1 = '';
$buff2 = '';

print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldgreen on_$bgcblack"); print"\n";
#####

###
print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('  Lending     ',"$red on_$bgcblack");
$buff0 = $fundindexlending; #Number of shares fund purchased
bankindexfndstatbk();                    
print colored("$buff0","$red on_$bgcblack");
$buff0 = '';
$buff1 = '';

$buff0 = @fundindexvalueinit[6]; #Initial Value
$buff0 = sprintf "%.3f",$buff0; #Format to 3 decimal places
bankindexfndstatbk();                   
print colored("$buff0","$red on_$bgcblack");
$buff0 = '';
$buff1 = '';

$buff0 = ($fundindexlending * $fundlendingsharevalue); #Current Value
$bankfndnfovlutly = $bankfndnfovlutly + $buff0;
if ($buff0 >= @fundindexvalueinit[6]) {
	$buff2 = $boldblack;
} else {
	$buff2 = $red;
}
$buff0 = sprintf "%.3f",$buff0; #Format to 3 decimal places
bankindexfndstatbk();
print colored("$buff0","$buff2 on_$bgcblack");
$buff0 = '';
$buff1 = '';
$buff2 = '';

print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";
#####



###
print colored('$',"$boldwhite on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('  Construction',"$red on_$bgcblack");
$buff0 = $fundindexconstruction; #Number of shares fund purchased
bankindexfndstatbk();                    
print colored("$buff0","$red on_$bgcblack");
$buff0 = '';
$buff1 = '';

$buff0 = @fundindexvalueinit[7]; #Initial Value
$buff0 = sprintf "%.3f",$buff0; #Format to 3 decimal places
bankindexfndstatbk();                   
print colored("$buff0","$red on_$bgcblack");
$buff0 = '';
$buff1 = '';

$buff0 = ($fundindexconstruction * $fundconstructionsharevalue); #Current Value
$bankfndnfovlutly = $bankfndnfovlutly + $buff0;
if ($buff0 >= @fundindexvalueinit[7]) {
	$buff2 = $boldblack;
} else {
	$buff2 = $red;
}
$buff0 = sprintf "%.3f",$buff0; #Format to 3 decimal places
bankindexfndstatbk();
print colored("$buff0","$buff2 on_$bgcblack");
$buff0 = '';
$buff1 = '';
$buff2 = '';

print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldwhite on_$bgcblack"); print"\n";
#####

###
print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('  Mining      ',"$red on_$bgcblack");
$buff0 = $fundindexmining; #Number of shares fund purchased
bankindexfndstatbk();                    
print colored("$buff0","$red on_$bgcblack");
$buff0 = '';
$buff1 = '';

$buff0 = @fundindexvalueinit[8]; #Initial Value
$buff0 = sprintf "%.3f",$buff0; #Format to 3 decimal places
bankindexfndstatbk();                   
print colored("$buff0","$red on_$bgcblack");
$buff0 = '';
$buff1 = '';

$buff0 = ($fundindexmining * $fundminingsharevalue); #Current Value
$bankfndnfovlutly = $bankfndnfovlutly + $buff0;
if ($buff0 >= @fundindexvalueinit[8]) {
	$buff2 = $boldblack;
} else {
	$buff2 = $red;
}
$buff0 = sprintf "%.3f",$buff0; #Format to 3 decimal places
bankindexfndstatbk();
print colored("$buff0","$buff2 on_$bgcblack");
$buff0 = '';
$buff1 = '';
$buff2 = '';

print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";
#####

bankblankgreen();

print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");                                            #
print colored('  TOTAL       ....................',"$white on_$bgcblack");

$buff3 = '';
foreach (@fundindexvalueinit) {
	$buff3 = $buff3 + $_;
}
$buff0 = $buff3; #Total kept for comparison in a min
$buff0 = sprintf "%.3f",$buff0; #Format to 3 decimal places
bankindexfndstatbk();                   
print colored("$buff0","$white on_$bgcblack");
$buff0 = '';
$buff1 = '';
$buff2 = '';

if ($bankfndnfovlutly >= $buff3) {
	$buff2 = $boldblack;
} else {
	$buff2 = $red;
}
$buff0 = ($bankfndnfovlutly); #Current Total Value
$buff0 = sprintf "%.3f",$buff0; #Format to 3 decimal places
bankindexfndstatbk();
print colored("$buff0","$buff2 on_$bgcblack");
$buff0 = '';
$buff1 = '';
$buff2 = '';
$buff3 = '';

print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";
$bankfndnfovlutly = 0; #Reset to 0 since we're done with it.

bankblankwhite();
bankblankyellow();
bankblankgreen();
bankblankyellow()
}

sub bankindexfndstatbk {
	$numchars = 0;
	if ($buff0 > 999999999999999.999) {
		$buff0 = sprintf "%.13e",$buff0; #Format to scientific notation
	}
	while ($buff0 =~ /[a-zA-Z0-9_ \:\?\.\,\"\;\`\~\\\/\[\]\{\}\!\@\#\$\%\^\&\*\-\_\=\+\(\)]/g) {
		$numchars = $numchars + 1;
	}

	$buff1 = ' 'x(20 - (($numchars)));
	$numchars = 0;
	$buff0 = "$buff1"."$buff0";
}

sub bankindexfndstat {
	$numchars = 0;
	while ($buff0 =~ /[a-zA-Z0-9_ \:\?\.\,\"\;\`\~\\\/\[\]\{\}\!\@\#\$\%\^\&\*\-\_\=\+\(\)]/g) {
		$numchars = $numchars + 1;
	}

	$buff1 = ' 'x(20 - (($numchars)));
	$numchars = 0;
	$buff0 = "$buff0"."$buff1";
}


sub bankstockhist {
print colored('$',"$boldwhite on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('  Historical Performance:                                                 ',"$white on_$bgcblack");
print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldwhite on_$bgcblack"); print"\n";



if ($stocktick > 10) {
	$buff1 = ($stocktick - 10);
	bankstocktrk();
} else {
	$buff0 = 'N/A';
}
bankcropsinglestat();
print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('  Time -10                ',"$red on_$bgcblack");                      
print colored("$buff0","$boldred on_$bgcblack");
$buff0 = '';
$buff1 = '';
print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";



if ($stocktick > 50) {
	$buff1 = ($stocktick - 50);
	bankstocktrk();
} else {
	$buff0 = 'N/A';
}
bankcropsinglestat();
print colored('$',"$boldgreen on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('  Time -50                ',"$red on_$bgcblack");                      
print colored("$buff0","$boldred on_$bgcblack");
$buff0 = '';
$buff1 = '';
print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldgreen on_$bgcblack"); print"\n";



if ($stocktick > 100) {
	$buff1 = ($stocktick - 100);
	bankstocktrk();
} else {
	$buff0 = 'N/A';
}
bankcropsinglestat();
print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('  Time -100               ',"$red on_$bgcblack");                      
print colored("$buff0","$boldred on_$bgcblack");
$buff0 = '';
$buff1 = '';
print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";



if ($stocktick > 150) {
	$buff1 = ($stocktick - 150);
	bankstocktrk();
} else {
	$buff0 = 'N/A';
}
bankcropsinglestat();
print colored('$',"$boldwhite on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('  Time -150               ',"$red on_$bgcblack");                      
print colored("$buff0","$boldred on_$bgcblack");
$buff0 = '';
$buff1 = '';
print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldwhite on_$bgcblack"); print"\n";



if ($stocktick > 200) {
	$buff1 = ($stocktick - 200);
	bankstocktrk();
} else {
	$buff0 = 'N/A';
}
bankcropsinglestat();
print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('  Time -200               ',"$red on_$bgcblack");                      
print colored("$buff0","$boldred on_$bgcblack");
$buff0 = '';
$buff1 = '';
print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";



if ($stocktick > 500) {
	$buff1 = ($stocktick - 500);
	bankstocktrk();
} else {
	$buff0 = 'N/A';
}
bankcropsinglestat();
print colored('$',"$boldgreen on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('  Time -500               ',"$boldred on_$bgcblack");                      
print colored("$buff0","$red on_$bgcblack");
$buff0 = '';
$buff1 = '';
print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldgreen on_$bgcblack"); print"\n";



if ($stocktick > 1000) {
	$buff1 = ($stocktick - 1000);
	bankstocktrk();
} else {
	$buff0 = 'N/A';
}
bankcropsinglestat();
print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('  Time -1000              ',"$boldred on_$bgcblack");                      
print colored("$buff0","$red on_$bgcblack");
$buff0 = '';
$buff1 = '';
print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";



if ($stocktick > 1500) {
	$buff1 = ($stocktick - 1500);
	bankstocktrk();
} else {
	$buff0 = 'N/A';
}
bankcropsinglestat();
print colored('$',"$boldwhite on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('  Time -1500              ',"$boldred on_$bgcblack");                      
print colored("$buff0","$red on_$bgcblack");
$buff0 = '';
$buff1 = '';
print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldwhite on_$bgcblack"); print"\n";



if ($stocktick > 2000) {
	$buff1 = ($stocktick - 2000);
	bankstocktrk();
} else {
	$buff0 = 'N/A';
}
bankcropsinglestat();
print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('  Time -2000              ',"$boldred on_$bgcblack");                      
print colored("$buff0","$red on_$bgcblack");
$buff0 = '';
$buff1 = '';
print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";




if ($stocktick > 5000) {
	$buff1 = ($stocktick - 5000);
	bankstocktrk();
} else {
	$buff0 = 'N/A';
}
bankcropsinglestat();
print colored('$',"$boldgreen on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('  Time -5000              ',"$boldred on_$bgcblack");                      
print colored("$buff0","$red on_$bgcblack");
$buff0 = '';
$buff1 = '';
print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldgreen on_$bgcblack"); print"\n";




if ($stocktick > 10000) {
	$buff1 = ($stocktick - 10000);
	bankstocktrk();
} else {
	$buff0 = 'N/A';
}
bankcropsinglestat();
print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('  Time -10000             ',"$red on_$bgcblack");                      
print colored("$buff0","$boldred on_$bgcblack");
$buff0 = '';
$buff1 = '';
print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";



if ($stocktick > 50000) {
	$buff1 = ($stocktick - 50000);
	bankstocktrk();
} else {
	$buff0 = 'N/A';
}
bankcropsinglestat();
print colored('$',"$boldwhite on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('  Time -50000             ',"$red on_$bgcblack");                      
print colored("$buff0","$boldred on_$bgcblack");
$buff0 = '';
$buff1 = '';
print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldwhite on_$bgcblack"); print"\n";



if ($stocktick > 100000) {
	$buff1 = ($stocktick - 100000);
	bankstocktrk();
} else {
	$buff0 = 'N/A';
}
bankcropsinglestat();
print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('  Time -100000            ',"$red on_$bgcblack");                      
print colored("$buff0","$boldred on_$bgcblack");
$buff0 = '';
$buff1 = '';
print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";



if ($stocktick > 150000) {
	$buff1 = ($stocktick - 150000);
	bankstocktrk();
} else {
	$buff0 = 'N/A';
}
bankcropsinglestat();
print colored('$',"$boldgreen on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('  Time -150000            ',"$red on_$bgcblack");                      
print colored("$buff0","$boldred on_$bgcblack");
$buff0 = '';
$buff1 = '';
print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldgreen on_$bgcblack"); print"\n";


if ($stocktick > 200000) {
	$buff1 = ($stocktick - 200000);
	bankstocktrk();
} else {
	$buff0 = 'N/A';
}
bankcropsinglestat();
print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('  Time -200000            ',"$red on_$bgcblack");                      
print colored("$buff0","$boldred on_$bgcblack");
$buff0 = '';
$buff1 = '';
print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";
}

sub banksavdeposit {
bankblanktitle();
bankblanktop();
bankblankyellow();

print colored('$',"$boldwhite on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");       #           #                         #'                  #'                      
print colored('  SAVINGS DEPOSIT         Interest Rate          Compounding Interval       ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldwhite on_$bgcblack"); print"\n";


$buff0 = $banktruesavrte;
bankcropstat();
print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('                          ',"$white on_$bgcblack");                      
print colored("$buff0","$blue on_$bgcblack");
$buff0 = '';
$buff1 = '';
$buff0 = $banksavcpndintvl;
bankcropstat();
print colored(' ',"$boldblack on_$bgcblack");
print colored("$buff0","$white on_$bgcblack");
print colored('   ',"$boldwhite on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";


print colored('$',"$boldgreen on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");       #           #                         #'                  #'                      
print colored('                          Last Intvl Interest    Current Account Total      ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldgreen on_$bgcblack"); print"\n";


$buff0 = $banksavintrst;
bankcropstat();
print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('                          ',"$white on_$bgcblack");                      
print colored("$buff0","$boldwhite on_$bgcblack");
$buff0 = '';
$buff1 = '';
$buff0 = $banksavmoney;
bankcropstat();
print colored(' ',"$boldblack on_$bgcblack");
print colored("$buff0","$green on_$bgcblack");
print colored('   ',"$boldwhite on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";


print colored('$',"$boldwhite on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");       #           #                         #'                  #'                      
print colored('                          Current Total Interest Current Deposited Principle',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldwhite on_$bgcblack"); print"\n";

$buff0 = $banksavecrintsttrk;
bankcropstat();
print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('                          ',"$white on_$bgcblack");                      
print colored("$buff0","$white on_$bgcblack");
$buff0 = '';
$buff1 = '';
$buff0 = $banksavsprncple;
bankcropstat();
print colored(' ',"$boldblack on_$bgcblack");
print colored("$buff0","$white on_$bgcblack");
print colored('   ',"$boldwhite on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";



print colored('$',"$boldgreen on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");       #           #                         #'                  #'                      
print colored('                          Total Interest Earned  Total Deposits             ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldgreen on_$bgcblack"); print"\n";


$buff0 = $banksavintrsttrk;
bankcropstat();
print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('                          ',"$white on_$bgcblack");                      
print colored("$buff0","$white on_$bgcblack");
$buff0 = '';
$buff1 = '';
$buff0 = $banksavsprncpletrk;
bankcropstat();
print colored(' ',"$boldblack on_$bgcblack");
print colored("$buff0","$white on_$bgcblack");
print colored('   ',"$boldwhite on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";



bankblankwhite();
print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");                                             #'                      
print colored('  Enter deposit amount.                                                     ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";
bankblankgreen();
bankblankyellow();
bankblankwhite();
bankblankyellow();
bankblankgreen();
bankblankyellow();
bankblankwhite();
bankblankyellow();
bankblankgreen();
bankblankyellow();
bankblankwhite();


print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('  Compound Interest Clock                                                   ',"$boldblack on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";
$buff0 = "$banksavingintvl".' / '."$banksavcpndintvl";
bankcropmessage0();
print colored('$',"$boldgreen on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored("  $buff0  ","$boldblack on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldgreen on_$bgcblack"); print"\n";
$buff0 = '';
$buff1 = '';

bankblankyellow();
bankblankbottom();
bankblanktitle();
print"enter deposit amount [$bankdepst]: ";
	
	$buff0 = '';
	$buff0 = <STDIN>;
	chomp($buff0);
	$buff0 =~ s/\D//g; #Remove non digits
	$buff0 =~ s/^0*//; #Remove leading zeroes
	
	if ($buff0 ne '') {
		if (0 < $buff0) {
			$bankdepst = $buff0;
			if ($money >= $bankdepst) {
				##The transaction
				$money = $money - $bankdepst;
				$banksavmoney = $banksavmoney + $bankdepst;
				##Tracking info
				$banksavsprncpletrk = $banksavsprncpletrk + $bankdepst;
				$banksavsprncple = $banksavsprncple + $bankdepst;
			} else {
			 #Do Nothing but complain
			 $buff0 = "Attempted deposit: $bankdepst";
			 $buff2 = 'is greater than current cash funds.';
			 bankcropmessage0();
			 bankcropmessage2();
			 newlines();
			 bankerror();
			 $buff0 = '';
			 $buff1 = '';
			 $buff2 = '';
			}
		} else {
		 #Do Nothing but complain 
		 #This won't occur due to the stripping out of non digit chars though
		 #Nice to have an error if it does somehow.
		 $buff0 = "Deposit cannot be zero or negative.";
		 $buff2 = '';
		 bankcropmessage0();
		 bankcropmessage2();
		 newlines();
		 bankerror();
		 $buff0 = '';
		 $buff1 = '';
		 $buff2 = '';
		}
	} else {
	 #Do Nothing
	}
	$buff0 = '';
	$bankdepst = 0;
}

sub banksavwithdraw {
bankblanktitle();
bankblanktop();
bankblankyellow();

print colored('$',"$boldwhite on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");       #           #                         #'                  #'                      
print colored('  SAVINGS WITHDRAWAL      Interest Rate          Compounding Interval       ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldwhite on_$bgcblack"); print"\n";


$buff0 = $banktruesavrte;
bankcropstat();
print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('                          ',"$white on_$bgcblack");                      
print colored("$buff0","$blue on_$bgcblack");
$buff0 = '';
$buff1 = '';
$buff0 = $banksavcpndintvl;
bankcropstat();
print colored(' ',"$boldblack on_$bgcblack");
print colored("$buff0","$white on_$bgcblack");
print colored('   ',"$boldwhite on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";


print colored('$',"$boldgreen on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");       #           #                         #'                  #'                      
print colored('                          Last Intvl Interest    Current Account Total      ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldgreen on_$bgcblack"); print"\n";


$buff0 = $banksavintrst;
bankcropstat();
print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('                          ',"$white on_$bgcblack");                      
print colored("$buff0","$boldwhite on_$bgcblack");
$buff0 = '';
$buff1 = '';
$buff0 = $banksavmoney;
bankcropstat();
print colored(' ',"$boldblack on_$bgcblack");
print colored("$buff0","$green on_$bgcblack");
print colored('   ',"$boldwhite on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";


print colored('$',"$boldwhite on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");       #           #                         #'                  #'                      
print colored('                          Current Total Interest Current Deposited Principle',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldwhite on_$bgcblack"); print"\n";

$buff0 = $banksavecrintsttrk;
bankcropstat();
print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('                          ',"$white on_$bgcblack");                      
print colored("$buff0","$white on_$bgcblack");
$buff0 = '';
$buff1 = '';
$buff0 = $banksavsprncple;
bankcropstat();
print colored(' ',"$boldblack on_$bgcblack");
print colored("$buff0","$white on_$bgcblack");
print colored('   ',"$boldwhite on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";



print colored('$',"$boldgreen on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");       #           #                         #'                  #'                      
print colored('                          Total Interest Earned  Total Withdrawls           ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldgreen on_$bgcblack"); print"\n";


$buff0 = $banksavintrsttrk;
bankcropstat();
print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('                          ',"$white on_$bgcblack");                      
print colored("$buff0","$white on_$bgcblack");
$buff0 = '';
$buff1 = '';
$buff0 = $banksavswthdrwtrk;
bankcropstat();
print colored(' ',"$boldblack on_$bgcblack");
print colored("$buff0","$white on_$bgcblack");
print colored('   ',"$boldwhite on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";


bankblankwhite();
print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");                                             #'                      
print colored('  Enter withdrawal amount.                                                  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";
bankblankgreen();
bankblankyellow();
bankblankwhite();
bankblankyellow();
bankblankgreen();
bankblankyellow();
bankblankwhite();
bankblankyellow();
bankblankgreen();
bankblankyellow();
bankblankwhite();

print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('  Compound Interest Clock                                                   ',"$boldblack on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";
$buff0 = "$banksavingintvl".' / '."$banksavcpndintvl";
bankcropmessage0();
print colored('$',"$boldgreen on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored("  $buff0  ","$boldblack on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldgreen on_$bgcblack"); print"\n";
$buff0 = '';
$buff1 = '';

bankblankyellow();
bankblankbottom();
bankblanktitle();
print"enter withdrawal amount [$bankwtdrl]: ";
	
	$buff0 = '';
	$buff0 = <STDIN>;
	chomp($buff0);
	$buff0 =~ s/\D//g; #Remove non digits
	$buff0 =~ s/^0*//; #Remove leading zeroes
	
	if ($buff0 ne '') {
		if (0 < $buff0) {
			$bankwtdrl = $buff0;
			if ($banksavmoney >= $bankwtdrl) {
				##The transaction
				$banksavmoney = $banksavmoney - $bankwtdrl;
				$money = $money + $bankwtdrl;
				
				##Tracking info
				$banksavswthdrwtrk = $banksavswthdrwtrk + $bankwtdrl;
				
				##Current Total Intrest (total - principle)
				## is withdrawn from statistic first
				$banksavecrintsttrk = $banksavecrintsttrk - $bankwtdrl;
				if (0 > $banksavecrintsttrk) {
					##If $banksavecrintsttrk is now negative,
					## we add it to $banksavsprncple 
					## (which is a subtraction since it's negative)
					##First we dipped into the intrest, then the principle
					$banksavsprncple = $banksavsprncple + $banksavecrintsttrk;
					$banksavecrintsttrk = 0;
				}				
			} else {
			 #Do Nothing but complain
			 $buff0 = "Attempted withdrawl: $bankwtdrl";
			 $buff2 = 'is greater than current account funds.';
			 bankcropmessage0();
			 bankcropmessage2();
			 newlines();
			 bankerror();
			 $buff0 = '';
			 $buff1 = '';
			 $buff2 = '';
			}
		} else {
		 #Do Nothing but complain 
		 #This won't occur due to the stripping out of non digit chars though
		 #Nice to have an error if it does somehow.
		 $buff0 = "Withdrawl cannot be zero or negative.";
		 $buff2 = '';
		 bankcropmessage0();
		 bankcropmessage2();
		 newlines();
		 bankerror();
		 $buff0 = '';
		 $buff1 = '';
		 $buff2 = '';
		}
	} else {
	 #Do Nothing
	}
	$buff0 = '';
	$bankwtdrl = 0;
}

sub banktokenmachine {
tokeneval();
bankblanktitle();
bankblanktop();
bankblankyellow();

print colored('$',"$boldwhite on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");                                             #'                      
print colored('  Enter the value of the slotmachine tokens you wish to use:                ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldwhite on_$bgcblack"); print"\n";

bankblankyellow();

print colored('$',"$boldgreen on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('  Either a set numerical value:  5                                          ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldgreen on_$bgcblack"); print"\n";

print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('  Or an automatically updated multiplicative value of your total:  m0.01    ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";


bankblankwhite();
bankblankyellow();
bankblankgreen();
bankblankyellow();
bankblankwhite();
bankblankyellow();
bankblankgreen();
bankblankyellow();
bankblankwhite();
bankblankyellow();
bankblankgreen();
bankblankyellow();
bankblankwhite();
bankblankyellow();
bankblankgreen();
bankblankyellow();
bankblankwhite();
bankblankyellow();
bankblankgreen();
bankblankyellow();
bankblankbottom();
bankblanktitle();
print"enter slotmachine token value [$coin]: ";

	$buff0 = <STDIN>;
	chomp($buff0);
	$buff1 = '';
	$buff2 = '';
	($buff1, $buff2) = split(//,$buff0, 2);
	if (($buff1 eq 'm') and ($buff2 ne '') and ($buff2 > 0)) {
		$buff2 =~ s/\W!\.//g;
		if (($buff2 * $money) <= $money) {
			#Only enable token evaluation if the multiple is less than or equal to total cash
			$coineval = 1;
			$coinmultiple = $buff2;
			tokeneval();
		}
	} elsif (($buff0 ne '') and ($buff0 ne 'c') and ($buff0 ne 'C')) {
		$coineval = 0;
		$buff0 =~ s/\D//g; #Remove non digits
		$buff0 =~ s/^0*//; #Remove leading zeroes
	
		if ($buff0 ne '') {
			$coin = $buff0;
		}
	}
	
	if (1 >= $coin) {
		$coin = 1;
	}
}

sub tokeneval {
	if ($coineval == 1) {
		$coin = $money * $coinmultiple;
		$coin = sprintf("%.0f", $coin ); #make sure full number;
		if (1 >= $coin) {
			$coin = 1;
		}
	}
}

sub bankcashin {
bankblanktitle();
bankblanktop();
bankblankyellow();

print colored('$',"$boldwhite on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");                                             #'                      
print colored('  Do you wish to cashin?                                                    ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldwhite on_$bgcblack"); print"\n";


bankblankyellow();
bankblankgreen();
bankblankyellow();
bankblankwhite();
bankblankyellow();
bankblankgreen();
bankblankyellow();


bankblankwhiteshort();print colored('      oooo',"$cyan on_$bgcblack");print colored('| |',"$boldwhite on_$bgcwhite");print colored('oooo     ',"$cyan on_$bgcblack");
bankblankwhiteshortend();

bankblankyellowshort();print colored('   ooooooo',"$cyan on_$bgcblack");print colored('| |',"$boldwhite on_$bgcwhite");print colored('ooooooo  ',"$cyan on_$bgcblack");
bankblankyellowshortend();

bankblankgreenshort();print colored('  oooooooo',"$cyan on_$bgcblack");print colored('| |',"$boldwhite on_$bgcwhite");print colored('oooooooo ',"$cyan on_$bgcblack");
bankblankgreenshortend();

bankblankyellowshort();print colored(' o',"$boldcyan on_$bgcblack");print colored('oooooooo',"$cyan on_$bgcblack");print colored('| |',"$boldwhite on_$bgcwhite");print colored('oooooooo ',"$cyan on_$bgcblack");
bankblankyellowshortend();

bankblankwhiteshort();print colored('o',"$boldcyan on_$bgcblack");print colored('ooooooo',"$cyan on_$bgcblack");print colored('       ',"$boldwhite on_$bgcwhite");print colored('ooooooo',"$cyan on_$bgcblack");
bankblankwhiteshortend();

bankblankyellowshort();print colored(' ',"$boldwhite on_$bgcwhite");print colored('=======  1    =======',"$boldwhite on_$bgcwhite");
bankblankyellowshortend();

bankblankgreenshort();print colored(' ',"$boldwhite on_$bgcwhite");print colored('=======    K  =======',"$boldwhite on_$bgcwhite");
bankblankgreenshortend();

bankblankyellowshort();print colored('o',"$boldcyan on_$bgcblack");print colored('ooooooo',"$cyan on_$bgcblack");print colored('       ',"$boldwhite on_$bgcwhite");print colored('ooooooo',"$cyan on_$bgcblack");
bankblankyellowshortend();

bankblankwhiteshort();print colored(' o',"$boldcyan on_$bgcblack");print colored('oooooooo',"$cyan on_$bgcblack");print colored('| |',"$boldwhite on_$bgcwhite");print colored('oooooooo ',"$cyan on_$bgcblack");
bankblankwhiteshortend();

bankblankyellowshort();print colored(' o',"$boldcyan on_$bgcblack");print colored('oooooooo',"$cyan on_$bgcblack");print colored('| |',"$boldwhite on_$bgcwhite");print colored('oooooooo ',"$cyan on_$bgcblack");
bankblankyellowshortend();

bankblankgreenshort();print colored('  o',"$boldcyan on_$bgcblack");print colored('ooooooo',"$cyan on_$bgcblack");print colored('| |',"$boldwhite on_$bgcwhite");print colored('ooooooo  ',"$cyan on_$bgcblack");
bankblankgreenshortend();

bankblankyellowshort();print colored('   ooo',"$boldcyan on_$bgcblack");print colored('oooo',"$cyan on_$bgcblack");print colored('| |',"$boldwhite on_$bgcwhite");print colored('oooo     ',"$cyan on_$bgcblack");
bankblankyellowshortend();

bankblankwhiteshort();print colored('      oooo',"$boldcyan on_$bgcblack");print colored('   ',"$boldwhite on_$bgcwhite");print colored('ooo      ',"$boldcyan on_$bgcblack");
bankblankwhiteshortend();

bankblankyellow();
bankblankgreen();
bankblankyellow();
bankblankbottom();
bankblanktitle();
print"cashin [y/n]: ";

	$buff0 = <STDIN>;
	chomp($buff0);
	
	if (($buff0 eq 'y') or ($buff0 eq 'Y') or ($buff0 eq 'yes') or ($buff0 eq 'YES')) {
		loadsavefile();
		zerosavefile();
		zeroaccounts();
		$loadedsavefile = 1;
	}
}

sub bankcashout {
bankblanktitle();
bankblanktop();
bankblankyellow();

print colored('$',"$boldwhite on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");                                             #'                      
print colored('  Do you wish to cashout?                                                   ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldwhite on_$bgcblack"); print"\n";


bankblankyellow();
bankblankgreen();
bankblankyellow();
bankblankwhite();
bankblankyellow();
bankblankgreen();
bankblankyellow();


bankblankwhiteshort();print colored('      oooo',"$red on_$bgcblack");print colored('| |',"$boldwhite on_$bgcwhite");print colored('oooo     ',"$red on_$bgcblack");
bankblankwhiteshortend();

bankblankyellowshort();print colored('   ooooooo',"$red on_$bgcblack");print colored('| |',"$boldwhite on_$bgcwhite");print colored('ooooooo  ',"$red on_$bgcblack");
bankblankyellowshortend();

bankblankgreenshort();print colored('  oooooooo',"$red on_$bgcblack");print colored('| |',"$boldwhite on_$bgcwhite");print colored('oooooooo ',"$red on_$bgcblack");
bankblankgreenshortend();

bankblankyellowshort();print colored(' o',"$boldred on_$bgcblack");print colored('oooooooo',"$red on_$bgcblack");print colored('| |',"$boldwhite on_$bgcwhite");print colored('oooooooo ',"$red on_$bgcblack");
bankblankyellowshortend();

bankblankwhiteshort();print colored('o',"$boldred on_$bgcblack");print colored('ooooooo',"$red on_$bgcblack");print colored('       ',"$boldwhite on_$bgcwhite");print colored('ooooooo',"$red on_$bgcblack");
bankblankwhiteshortend();

bankblankyellowshort();print colored(' ',"$boldwhite on_$bgcwhite");print colored('=======  5    =======',"$boldwhite on_$bgcwhite");
bankblankyellowshortend();

bankblankgreenshort();print colored(' ',"$boldwhite on_$bgcwhite");print colored('=======    0  =======',"$boldwhite on_$bgcwhite");
bankblankgreenshortend();

bankblankyellowshort();print colored('o',"$boldred on_$bgcblack");print colored('ooooooo',"$red on_$bgcblack");print colored('       ',"$boldwhite on_$bgcwhite");print colored('ooooooo',"$red on_$bgcblack");
bankblankyellowshortend();

bankblankwhiteshort();print colored(' o',"$boldred on_$bgcblack");print colored('oooooooo',"$red on_$bgcblack");print colored('| |',"$boldwhite on_$bgcwhite");print colored('oooooooo ',"$red on_$bgcblack");
bankblankwhiteshortend();

bankblankyellowshort();print colored(' o',"$boldred on_$bgcblack");print colored('oooooooo',"$red on_$bgcblack");print colored('| |',"$boldwhite on_$bgcwhite");print colored('oooooooo ',"$red on_$bgcblack");
bankblankyellowshortend();

bankblankgreenshort();print colored('  o',"$boldred on_$bgcblack");print colored('ooooooo',"$red on_$bgcblack");print colored('| |',"$boldwhite on_$bgcwhite");print colored('ooooooo  ',"$red on_$bgcblack");
bankblankgreenshortend();

bankblankyellowshort();print colored('   ooo',"$boldred on_$bgcblack");print colored('oooo',"$red on_$bgcblack");print colored('| |',"$boldwhite on_$bgcwhite");print colored('oooo     ',"$red on_$bgcblack");
bankblankyellowshortend();

bankblankwhiteshort();print colored('      oooo',"$boldred on_$bgcblack");print colored('   ',"$boldwhite on_$bgcwhite");print colored('ooo      ',"$boldred on_$bgcblack");
bankblankwhiteshortend();

bankblankyellow();
bankblankgreen();
bankblankyellow();
bankblankbottom();
bankblanktitle();
print"cashout [y/n]: ";

	$buff0 = <STDIN>;
	chomp($buff0);
	
	if (($buff0 eq 'y') or ($buff0 eq 'Y') or ($buff0 eq 'yes') or ($buff0 eq 'YES')) {
		printsavefile();
		zeroaccounts();
		$money = 0;
	}
}



sub findbankstkpttotal {
$bankstkpttotal = (($fundretailsharevalue * $fundretailshares)
		+ ($fundindustrysharevalue * $fundindustryshares)
		+ ($fundtechsharevalue * $fundtechshares)
		+ ($fundenergysharevalue * $fundenergyshares)
		+ ($fundtextilesharevalue * $fundtextileshares)
		+ ($fundinvestmentsharevalue * $fundinvestmentshares)
		+ ($fundlendingsharevalue * $fundlendingshares)
		+ ($fundconstructionsharevalue * $fundconstructionshares)
		+ ($fundminingsharevalue * $fundminingshares)
		+ ($fundindexsharevalue * $fundindexshares));
}

sub bankfinarept {
bankblanktitle();
bankblanktop();
bankblankyellow();
bankblankwhite();

print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");                                             #'                      
print colored('                          Cumulative Winnings    Expended Cash              ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";

$buff0 = $hrstmc;
bankcropstat();
print colored('$',"$boldgreen on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('  House Rules Reel Deal:  ',"$white on_$bgcblack");                      
print colored("$buff0","$white on_$bgcblack");
$buff0 = '';
$buff1 = '';
$buff0 = $hrstmc2;
bankcropstat();
print colored('(',"$boldblack on_$bgcblack");
print colored("$buff0","$red on_$bgcblack");
print colored(')  ',"$boldblack on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldgreen on_$bgcblack"); print"\n";

$buff0 = $ddstmc;
bankcropstat();
print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('    Double Blue Diamond:  ',"$white on_$bgcblack");                      
print colored("$buff0","$white on_$bgcblack");
$buff0 = '';
$buff1 = '';
$buff0 = $ddstmc2;
bankcropstat();
print colored('(',"$boldblack on_$bgcblack");
print colored("$buff0","$red on_$bgcblack");
print colored(')  ',"$boldblack on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";

$buff0 = $ssstmc;
bankcropstat();
print colored('$',"$boldwhite on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('     High Roller Sevens:  ',"$white on_$bgcblack");                      
print colored("$buff0","$white on_$bgcblack");
$buff0 = '';
$buff1 = '';
$buff0 = $ssstmc2;
bankcropstat();
print colored('(',"$boldblack on_$bgcblack");
print colored("$buff0","$red on_$bgcblack");
print colored(')  ',"$boldblack on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldwhite on_$bgcblack"); print"\n";

$buff0 = $ngemstmc;
bankcropstat();
print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('          Twilight Mine:  ',"$white on_$bgcblack");                      
print colored("$buff0","$white on_$bgcblack");
$buff0 = '';
$buff1 = '';
$buff0 = $ngemstmc2;
bankcropstat();
print colored('(',"$boldblack on_$bgcblack");
print colored("$buff0","$red on_$bgcblack");
print colored(')  ',"$boldblack on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";

$buff0 = $potluckstmc;
bankcropstat();
print colored('$',"$boldgreen on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('                PotLuck:  ',"$white on_$bgcblack");                      
print colored("$buff0","$white on_$bgcblack");
$buff0 = '';
$buff1 = '';
$buff0 = $potluckstmc2;
bankcropstat();
print colored('(',"$boldblack on_$bgcblack");
print colored("$buff0","$red on_$bgcblack");
print colored(')  ',"$boldblack on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldgreen on_$bgcblack"); print"\n";

$buff0 = $rrstmc;
bankcropstat();
print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('       Russian Roulette:  ',"$white on_$bgcblack");                      
print colored("$buff0","$white on_$bgcblack");
$buff0 = '';
$buff1 = '';
$buff0 = $rrstmc2;
bankcropstat();
print colored('(',"$boldblack on_$bgcblack");
print colored("$buff0","$red on_$bgcblack");
print colored(')  ',"$boldblack on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";

$buff0 = $lvrstmc;
bankcropstat();
print colored('$',"$boldwhite on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('   Monte Carlo Roulette:  ',"$white on_$bgcblack");                      
print colored("$buff0","$white on_$bgcblack");
$buff0 = '';
$buff1 = '';
$buff0 = $lvrstmc2;
bankcropstat();
print colored('(',"$boldblack on_$bgcblack");
print colored("$buff0","$red on_$bgcblack");
print colored(')  ',"$boldblack on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldwhite on_$bgcblack"); print"\n";

$buff0 = $rllvrstmc;
bankcropstat();
print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('    Real Vegas Roulette:  ',"$white on_$bgcblack");                      
print colored("$buff0","$white on_$bgcblack");
$buff0 = '';
$buff1 = '';
$buff0 = $rllvrstmc2;
bankcropstat();
print colored('(',"$boldblack on_$bgcblack");
print colored("$buff0","$red on_$bgcblack");
print colored(')  ',"$boldblack on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";

$buff0 = $sbtstmc;
bankcropstat();
print colored('$',"$boldgreen on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('         Sic Bo Tai Sai:  ',"$white on_$bgcblack");                      
print colored("$buff0","$white on_$bgcblack");
$buff0 = '';
$buff1 = '';
$buff0 = $sbtstmc2;
bankcropstat();
print colored('(',"$boldblack on_$bgcblack");
print colored("$buff0","$red on_$bgcblack");
print colored(')  ',"$boldblack on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldgreen on_$bgcblack"); print"\n";

$buff0 = $ccrapsstmc;
bankcropstat();
print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('           Casino Craps:  ',"$white on_$bgcblack");                      
print colored("$buff0","$white on_$bgcblack");
$buff0 = '';
$buff1 = '';
$buff0 = $ccrapsstmc2;
bankcropstat();
print colored('(',"$boldblack on_$bgcblack");
print colored("$buff0","$red on_$bgcblack");
print colored(')  ',"$boldblack on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";

bankblankwhite();

moneyclock();
$buff0 = $totalmc;
bankcropstat();
print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('                  TOTAL:  ',"$white on_$bgcblack");                      
print colored("$buff0","$white on_$bgcblack");
$buff0 = '';
$buff1 = '';
$buff0 = $moneyexp;
bankcropstat();
print colored('(',"$boldblack on_$bgcblack");
print colored("$buff0","$red on_$bgcblack");
print colored(')  ',"$boldblack on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";


bankblankgreen();

print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");                                             #'                      
print colored('                          Stock Portfolio Value                             ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";

findbankstkpttotal();

$buff0 = $bankstkpttotal;
bankcropsinglestat();
print colored('$',"$boldwhite on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('                          ',"$white on_$bgcblack");                      
print colored("$buff0","$boldwhite on_$bgcblack");
$buff0 = '';
$buff1 = '';
print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldwhite on_$bgcblack"); print"\n";



print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");                                             #'                      
print colored('                          Current Savings         Current Account Principle ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";


$buff0 = $banksavmoney;
bankcropstat();
print colored('$',"$boldgreen on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('                          ',"$white on_$bgcblack");                      
print colored("$buff0","$boldwhite on_$bgcblack");
$buff0 = '';
$buff1 = '';
$buff0 = $banksavsprncple;
bankcropstat();
print colored(' ',"$boldblack on_$bgcblack");
print colored("$buff0","$green on_$bgcblack");
print colored('   ',"$boldwhite on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldgreen on_$bgcblack"); print"\n";


print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");                                             #'                      
print colored('                          Current Cash            Initial Cash              ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";


$buff0 = $money;
bankcropstat();
print colored('$',"$boldwhite on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('                          ',"$white on_$bgcblack");                      
print colored("$buff0","$boldwhite on_$bgcblack");
$buff0 = '';
$buff1 = '';
$buff0 = $startmoney;
bankcropstat();
print colored(' ',"$boldblack on_$bgcblack");
print colored("$buff0","$green on_$bgcblack");
print colored('   ',"$boldwhite on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldwhite on_$bgcblack"); print"\n";

bankblankyellow();

$buff0 = (($money) + (int($banksavmoney)) + (floor($bankstkpttotal)));
bankcropsinglestat();
print colored('$',"$boldwhite on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite"); 
print colored('     TOTAL ESTATE VALUE:  ',"$white on_$bgcblack");                      
print colored("$buff0","$boldyellow on_$bgcblack");
$buff0 = '';
$buff1 = '';
print colored('  ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldwhite on_$bgcblack"); print"\n";



bankblankyellow();
bankblankbottom();
bankblanktitle();
$buff0 = <STDIN>;
$buff0 = '';
}

sub bankcropsinglestat {
	$numchars = 0;
	while ($buff0 =~ /[a-zA-Z0-9_ \:\?\.\,\"\;\`\~\\\/\[\]\{\}\!\@\#\$\%\^\&\*\-\_\=\+\(\)]/g) {
		$numchars = $numchars + 1;
	}

	$buff1 = ' 'x(48 - (($numchars)));
	$numchars = 0;
	$buff0 = "$buff0"."$buff1";
}

sub bankcropsinglestatbk {
	$numchars = 0;
	while ($buff0 =~ /[a-zA-Z0-9_ \:\?\.\,\"\;\`\~\\\/\[\]\{\}\!\@\#\$\%\^\&\*\-\_\=\+\(\)]/g) {
		$numchars = $numchars + 1;
	}

	$buff1 = ' 'x(48 - (($numchars)));
	$numchars = 0;
	$buff0 = "$buff1"."$buff0";
}

sub bankcropstat {
	$numchars = 0;
	while ($buff0 =~ /[a-zA-Z0-9_ \:\?\.\,\"\;\`\~\\\/\[\]\{\}\!\@\#\$\%\^\&\*\-\_\=\+\(\)]/g) {
		$numchars = $numchars + 1;
	}

	$buff1 = ' 'x(23 - (($numchars)));
	$numchars = 0;
	$buff0 = "$buff0"."$buff1";
}

sub bankcropstatbk {
	$numchars = 0;
	while ($buff0 =~ /[a-zA-Z0-9_ \:\?\.\,\"\;\`\~\\\/\[\]\{\}\!\@\#\$\%\^\&\*\-\_\=\+\(\)]/g) {
		$numchars = $numchars + 1;
	}

	$buff1 = ' 'x(23 - (($numchars)));
	$numchars = 0;
	$buff0 = "$buff1"."$buff0";
}

sub bankcropmessage0 {
	$numchars = 0;
	while ($buff0 =~ /[a-zA-Z0-9_ \:\?\.\,\"\;\`\~\\\/\[\]\{\}\!\@\#\$\%\^\&\*\-\_\=\+\(\)]/g) {
		$numchars = $numchars + 1;
	}

	$buff1 = ' 'x(72 - (($numchars)));
	$numchars = 0;
	$buff0 = "$buff0"."$buff1";
}

sub bankcropmessage2 {
	$numchars = 0;
	while ($buff2 =~ /[a-zA-Z0-9_ \:\?\.\,\"\;\`\~\\\/\[\]\{\}\!\@\#\$\%\^\&\*\-\_\=\+\(\)]/g) {
		$numchars = $numchars + 1;
	}

	$buff1 = ' 'x(72 - (($numchars)));
	$numchars = 0;
	$buff2 = "$buff2"."$buff1";
}

sub bankblankyellow {
print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('                                                                            ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";
}

sub bankblankwhite {
print colored('$',"$boldwhite on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('                                                                            ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldwhite on_$bgcblack"); print"\n";
}

sub bankblankgreen {
print colored('$',"$boldgreen on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('                                                                            ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldgreen on_$bgcblack"); print"\n";
}

sub bankblankwhiteshort {
print colored('$',"$boldwhite on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('                                                ',"$white on_$bgcblack");
}
sub bankblankwhiteshortend {
print colored('      ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldwhite on_$bgcblack"); print"\n";
}

sub bankblankyellowshort {
print colored('$',"$boldyellow on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('                                                ',"$white on_$bgcblack");
}
sub bankblankyellowshortend {
print colored('      ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";
}

sub bankblankgreenshort {
print colored('$',"$boldgreen on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('                                                ',"$white on_$bgcblack");
}
sub bankblankgreenshortend {
print colored('      ',"$white on_$bgcblack");
print colored('|',"$boldwhite on_$bgcwhite");
print colored('$',"$boldgreen on_$bgcblack"); print"\n";
}

sub bankblanktop {
print colored('$',"$boldgreen on_$bgcblack");
print colored('\\----------------------------------------------------------------------------/',"$boldwhite on_$bgcwhite");
print colored('$',"$boldgreen on_$bgcblack"); print"\n";
}

sub bankblankbottom {
print colored('$',"$boldwhite on_$bgcblack");
print colored('/----------------------------------------------------------------------------\\',"$boldwhite on_$bgcwhite");
print colored('$',"$boldwhite on_$bgcblack"); print"\n";
}

sub bankblanktitle {
print colored('$',"$boldyellow on_$bgcblack");
print colored('BANK',"$boldgreen on_$bgcblack");
print colored('$',"$boldyellow on_$bgcblack");
print colored('BANK',"$boldwhite on_$bgcblack");
print colored('$',"$boldyellow on_$bgcblack");
print colored('BANK',"$boldgreen on_$bgcblack");
print colored('$',"$boldyellow on_$bgcblack");
print colored('BANK',"$boldwhite on_$bgcblack");
print colored('$',"$boldyellow on_$bgcblack");
print colored('BANK',"$boldgreen on_$bgcblack");
print colored('$',"$boldyellow on_$bgcblack");
print colored('BANK',"$boldwhite on_$bgcblack");
print colored('$',"$boldyellow on_$bgcblack");
print colored('BANK',"$boldgreen on_$bgcblack");
print colored('$.$.$$.$.$',"$boldyellow on_$bgcblack");
print colored('BANK',"$boldgreen on_$bgcblack");
print colored('$',"$boldyellow on_$bgcblack");
print colored('BANK',"$boldwhite on_$bgcblack");
print colored('$',"$boldyellow on_$bgcblack");
print colored('BANK',"$boldgreen on_$bgcblack");
print colored('$',"$boldyellow on_$bgcblack");
print colored('BANK',"$boldwhite on_$bgcblack");
print colored('$',"$boldyellow on_$bgcblack");
print colored('BANK',"$boldgreen on_$bgcblack");
print colored('$',"$boldyellow on_$bgcblack");
print colored('BANK',"$boldwhite on_$bgcblack");
print colored('$',"$boldyellow on_$bgcblack");
print colored('BANK',"$boldgreen on_$bgcblack");
print colored('$',"$boldyellow on_$bgcblack"); print"\n";
}

sub bankstartinfo {
	$bankstartinfo = <STDIN>;
	chomp($bankstartinfo);

	if ($bankstartinfo eq '1') {
		newlines();
		banktokenmachine();
		newlines();
		bankmachine();
	} elsif ($bankstartinfo eq '2') {
		newlines();
		bankfinarept();
		newlines();
		bankmachine();	
	} elsif ($bankstartinfo eq '3') {
		newlines();
		banksavdeposit();
		newlines();
		bankmachine();
	} elsif ($bankstartinfo eq '4') {
		newlines();
		banksavwithdraw();
		newlines();
		bankmachine();
	} elsif ($bankstartinfo eq '5') {
		newlines();
		bankstockedit();
		newlines();
		bankmachine();
	} elsif (($bankstartinfo eq '6') && ($allowsave == 1)) {
		newlines();
		bankcashout();
		newlines();
		bankmachine();
	} elsif (($bankstartinfo eq '7') && ($allowsave == 1) && ($loadedsavefile == 0)) {
		newlines();
		bankcashin();
		newlines();
		bankmachine();
	} elsif (($bankstartinfo eq 'exit') or ($bankstartinfo eq 'EXIT') or ($bankstartinfo eq 'quit') or ($bankstartinfo eq 'QUIT')) {
		exitgame();
	} elsif (($bankstartinfo eq "c") or ($bankstartinfo eq "C"))  {
		newlines();
		if ($music == 1) {
			killmusic();
			$music = 1;
			beginmusic();
		} else {
			#NOTHING!
		}
		return;
	} else {
		newlines();
		bankmachine();
	}

}

################################################################################################################################
sub print2html {
	winlosecalc();
	moneyclock();
	
	$htmllogo1 = '[BR]'."$name".'[BR]                               GENERAL PUBLIC                                   [BR][BR]';
	$htmllogo2 = '                           SSSSSS     IIIIIIIIIII                               [BR]';
	$htmllogo3 = '                         SSSSSSSSSS  IIIIIIIIIIIII                              [BR]';
	$htmllogo4 = '                        SSSS    SSSS     IIIII                                  [BR]';
	$htmllogo5 = '                  A     SSS              IIIII      NNNN     NNNNN              [BR]';
	$htmllogo6 = '                 AAA    SSSS             IIIII      NNNNN     NNN               [BR]';
	$htmllogo7 = '                AAAAA    SSSSSSSSS       IIIII      NNNNNN    NNN               [BR]';
	$htmllogo8 = '               AAAAAAA    SSSSSSSSS      IIIII      NNNNNNN   NNN               [BR]';
	$htmllogo9 = '    CCCCCC    AAAA AAAA         SSSS     IIIII      NNN NNNN  NNN     OOOOOOO   [BR]';
	$htmllogo10 = '  CCCCCCCCCC  AAA   AAA          SSS     IIIII      NNN  NNNN NNN   OOOOOOOOOOO [BR]';
	$htmllogo11 = ' CCCC    CCCC AAAAAAAAA SSSS    SSSS     IIIII      NNN   NNNNNNN  OOOOO   OOOOO[BR]';
	$htmllogo12 = ' CCC          AAA   AAA  SSSSSSSSSS  IIIIIIIIIIIII  NNN    NNNNNN  OOOO     OOOO[BR]';
	$htmllogo13 = ' CCC          AAA   AAA    SSSSSS     IIIIIIIIIII   NNN     NNNNN  OOOO     OOOO[BR]';
	$htmllogo14 = ' CCCC    CCCC AAA   AAA                            NNNNN     NNNN  OOOOO   OOOOO[BR]';
	$htmllogo15 = '  CCCCCCCCCC                                                        OOOOOOOOOOO [BR]';
	$htmllogo16 = '    CCCCCC                                                            OOOOOOO   [BR]';
	$htmllogo17 = "                                                                version $version   [BR][BR]";

	$htmllogo1 =~ s/ /&nbsp;/g;
	$htmllogo2 =~ s/ /&nbsp;/g;
	$htmllogo3 =~ s/ /&nbsp;/g;
	$htmllogo4 =~ s/ /&nbsp;/g;
	$htmllogo5 =~ s/ /&nbsp;/g;
	$htmllogo6 =~ s/ /&nbsp;/g;
	$htmllogo7 =~ s/ /&nbsp;/g;
	$htmllogo8 =~ s/ /&nbsp;/g;
	$htmllogo9 =~ s/ /&nbsp;/g;
	$htmllogo10 =~ s/ /&nbsp;/g;
	$htmllogo11 =~ s/ /&nbsp;/g;
	$htmllogo12 =~ s/ /&nbsp;/g;
	$htmllogo13 =~ s/ /&nbsp;/g;
	$htmllogo14 =~ s/ /&nbsp;/g;
	$htmllogo15 =~ s/ /&nbsp;/g;
	$htmllogo16 =~ s/ /&nbsp;/g;
	$htmllogo17 =~ s/ /&nbsp;/g;

	$htmllogo1 =~ s/\[BR\]/<br>\n/g;
	$htmllogo2 =~ s/\[BR\]/<br>\n/g;
	$htmllogo3 =~ s/\[BR\]/<br>\n/g;
	$htmllogo4 =~ s/\[BR\]/<br>\n/g;
	$htmllogo5 =~ s/\[BR\]/<br>\n/g;
	$htmllogo6 =~ s/\[BR\]/<br>\n/g;
	$htmllogo7 =~ s/\[BR\]/<br>\n/g;
	$htmllogo8 =~ s/\[BR\]/<br>\n/g;
	$htmllogo9 =~ s/\[BR\]/<br>\n/g;
	$htmllogo10 =~ s/\[BR\]/<br>\n/g;
	$htmllogo11 =~ s/\[BR\]/<br>\n/g;
	$htmllogo12 =~ s/\[BR\]/<br>\n/g;
	$htmllogo13 =~ s/\[BR\]/<br>\n/g;
	$htmllogo14 =~ s/\[BR\]/<br>\n/g;
	$htmllogo15 =~ s/\[BR\]/<br>\n/g;
	$htmllogo16 =~ s/\[BR\]/<br>\n/g;
	$htmllogo17 =~ s/\[BR\]/<br>\n/g;

	$htmlstats = '[BR][Total Times Slot Reels Were Spun:] '."$spins".'[BR][Total Expended Cash:] '."$moneyexp".'[BR][Money at Start:] '."$startmoney".'[BR][Aquired Wealth:] '."$money".'[BR][BR][Total Wins:] '."$winstat".'[BR][Total Losses:] '."$losestat".'[BR][Cumulative Total Winnings:] '."$totalmc".'[BR][BR][House Rules Reel Deal]'.'[BR][Wins:] '."$hrstwin".'[BR][Losses:] '."$hrstlose". '[BR][Spins:] '."$hrstspins".'[BR][Cumulative Winnings:] '."$hrstmc".'[BR][Expended Cash:] '."$hrstmc2".'[BR][BR][Double Blue Diamond]'.'[BR][Wins:] '."$ddstwin".'[BR][Losses:] '."$ddstlose".'[BR][Spins:] '."$ddstspins".'[BR][Cumulative Winnings:] '."$ddstmc".'[BR][Expended Cash:] '."$ddstmc2".'[BR][BR][High Roller Sevens]'.'[BR][Wins:] '."$ssstwin".'[BR][Losses:] '."$ssstlose".'[BR][Spins:] '."$ssstspins".'[BR][Cumulative Winnings:] '."$ssstmc".'[BR][Expended Cash:] '."$ssstmc2".'[BR][BR][Twilight Mine]'.'[BR][Wins:] '."$ngemstwin".'[BR][Losses:] '."$ngemstlose".'[BR][Spins:] '."$ngemstspins".'[BR][Cumulative Winnings:] '."$ngemstmc".'[BR][Expended Cash:] '."$ngemstmc2".'[BR][BR][PotLuck]'.'[BR][Wins:] '."$potluckstwin".'[BR][Losses:] '."$potluckstlose".'[BR][Spins:] '."$potluckstspins".'[BR][Cumulative Winnings:] '."$potluckstmc".'[BR][Expended Cash:] '."$potluckstmc2".'[BR][BR][Russian Roulette 25 or Life]'.'[BR][Wins:] '."$rrstwin".'[BR][Losses:] '."$rrstlose".'[BR][Spins:] '."$ruskiestspin".'[BR][Cumulative Winnings:] '."$rrstmc".'[BR][Expended:] '."$rrstmc2".'[BR][BR][Monte Carlo Roulette]'.'[BR][Wins:] '."$lvrstwin".'[BR][Losses:] '."$lvrstlose".'[BR][Spins:]'."$lvrstspins".'[BR][Cumulative Winnings:] '."$lvrstmc".'[BR][Expended Cash:] '."$lvrstmc2".'[BR][BR][Real Vegas Roulette]'.'[BR][Wins:] '."$rllvrstwin".'[BR][Losses:] '."$rllvrstlose".'[BR][Spins:]'."$rllvrstspins".'[BR][Cumulative Winnings:] '."$rllvrstmc".'[BR][Expended Cash:] '."$rllvrstmc2".'[BR][BR][Sic Bo Tai Sai]'.'[BR][Wins:] '."$sbtstwin".'[BR][Losses:] '."$sbtstlose".'[BR][Spins:]'."$sbtstspins".'[BR][Cumulative Winnings:] '."$sbtstmc".'[BR][Expended Cash:] '."$sbtstmc2".'[BR][BR][Casino Craps]'.'[BR][Wins:] '."$ccrapsstwin".'[BR][Losses:] '."$ccrapsstlose".'[BR][Spins:]'."$ccrapsstspins".'[BR][Cumulative Winnings:] '."$ccrapsstmc".'[BR][Expended Cash:] '."$ccrapsstmc2".'[BR]';
	$htmlstats =~ s/\[BR\]/<br>\n/g;
	$htmlstats =~ s/ /&nbsp;/g;

	$htmlheader = '<!DOCTYPE HTML PUBLIC "html.dtd">[BR]<html>[BR]<head>[BR]<title>'."$htmltitle".'</title>[BR]<style TYPE="text/css">[BR]</STYLE>[BR]</head>[BR]<body><body BGCOLOR="'."$htmlcolor0".'" TEXT="'."$htmlcolor1".'" LINK='."$htmlcolor5".'>';
	$htmlbody = '<tt><font COLOR='."$htmlcolor4".'>'."$htmllogo1".'</font><font COLOR='."$htmlcolor3".'>'."$htmllogo2".'</font><font COLOR='."$htmlcolor2".'>'."$htmllogo3".'</font><font COLOR='."$htmlcolor3".'>'."$htmllogo4".'</font><font COLOR='."$htmlcolor2".'>'."$htmllogo5".'</font><font COLOR='."$htmlcolor3".'>'."$htmllogo6".'</font><font COLOR='."$htmlcolor2".'>'."$htmllogo7".'</font><font COLOR='."$htmlcolor3".'>'."$htmllogo8".'</font><font COLOR='."$htmlcolor2".'>'."$htmllogo9".'</font><font COLOR='."$htmlcolor3".'>'."$htmllogo10".'</font><font COLOR='."$htmlcolor2".'>'."$htmllogo11".'</font><font COLOR='."$htmlcolor3".'>'."$htmllogo12".'</font><font COLOR='."$htmlcolor2".'>'."$htmllogo13".'</font><font COLOR='."$htmlcolor3".'>'."$htmllogo14".'</font><font COLOR='."$htmlcolor2".'>'."$htmllogo15".'</font><font COLOR='."$htmlcolor3".'>'."$htmllogo16".'</font><font COLOR='."$htmlcolor7".'>'."$htmllogo17".'</tt>'."$htmlstats";
	$htmlfooter = '<br>[BR]<br>[BR]<font SIZE="-1" COLOR='."$htmlcolor6".'>::Generated&nbsp;By&nbsp;GPC-Slots&nbsp;2::&nbsp;-&nbsp;::WEB[<a HREF="https://cat2.dynu.ca">CAEthaver2</a>]::&nbsp;-&nbsp;::IRC[<i>#linux</i>&nbsp;@&nbsp;<b>cat2.dynu.ca</b>]::&nbsp;-&nbsp;::FORUMS[<a HREF="https://cat2.dynu.ca/bb/index.php">CAEthaver2&nbsp;General&nbsp;Forums</a>]::&nbsp;-&nbsp;::RPG1[written&nbsp;by&nbsp;MikeeUSA]::</font><br>[BR]</body>[BR]</html>[BR]';	

	$htmlfooter =~ s/\[BR\]/\n/g;
	$htmlheader =~ s/\[BR\]/\n/g;
	
	if ($playtrack == 1) {
		$htmlgraph = "<br>\n[Progress&nbsp;Graph]\n<br>\n<table width=\"100%\" border='0'>\n<tbody>\n<tr>\n<td>\n<table border='0'>\n<tbody>\n<tr valign=\"bottom\">\n";
		@ptracker2 = @ptracker;
		foreach (@ptracker2) {
			$htmlgraph = "$htmlgraph"."<td>\n<tt>\n";
			if ($_ >= ($startmoney * 500)) {     #50000+
				$htmlgraph = "$htmlgraph"."<font color=\"white\">\n";
			} elsif ($_ >= ($startmoney * 100)) {#10000-49999
				$htmlgraph = "$htmlgraph"."<font color=\"purple\">\n";
			} elsif ($_ >= ($startmoney * 50)) { #5000-9999
				$htmlgraph = "$htmlgraph"."<font color=\"blue\">\n";
			} elsif ($_ >= ($startmoney * 10)) { #1000-4999
				$htmlgraph = "$htmlgraph"."<font color=\"cyan\">\n";
			} elsif ($_ >= ($startmoney * 5)) {  #500-999
				$htmlgraph = "$htmlgraph"."<font color=\"green\">\n";	
			} elsif ($_ >= ($startmoney * 1)) {  #100-499
				$htmlgraph = "$htmlgraph"."<font color=\"yellow\">\n";
			} elsif ($_ >= ($startmoney * 0.5)) {   #50-99
				$htmlgraph = "$htmlgraph"."<font color=\"orange\">\n";
			} elsif ($_ >= ($startmoney * 0.1)) {   #10-49
				$htmlgraph = "$htmlgraph"."<font color=\"red\">\n";		
			} else {
				$htmlgraph = "$htmlgraph"."<font color=\"darkred\">\n";
			}
			$htmlgraph2 = "";
			if ($htmlgraphnums == 1) {
				if ($_ >= $htmldivide) {
					$htmlgraph2 = (("[_|_]<br>\n") x (sprintf("%.0f", $_ )/$htmldivide));
					$htmlgraph = "$htmlgraph"."$htmlgraph2";
				} elsif (($_ < ($htmldivide)) and ($_ >= ($htmldivide/2))) {
					$htmlgraph2 = (".---.<br>\n");
					$htmlgraph = "$htmlgraph"."$htmlgraph2";
				} elsif (($_ < ($htmldivide/2)) and ($_ >= ($htmldivide/10))) {
					$htmlgraph2 = ("_____<br>\n");
					$htmlgraph = "$htmlgraph"."$htmlgraph2";
				}
			
				$htmlgraph = "$htmlgraph"."-----<br>$_<br>\n</font>\n</tt>\n</td>\n";
			} else {
				if ($_ >= $htmldivide) {
					$htmlgraph2 = (("[_]<br>\n") x (sprintf("%.0f", $_ )/$htmldivide));
					$htmlgraph = "$htmlgraph"."$htmlgraph2";
				} elsif (($_ < ($htmldivide)) and ($_ >= ($htmldivide/2))) {
					$htmlgraph2 = (".-.<br>\n");
					$htmlgraph = "$htmlgraph"."$htmlgraph2";
				} elsif (($_ < ($htmldivide/2)) and ($_ >= ($htmldivide/10))) {
					$htmlgraph2 = ("___<br>\n");
					$htmlgraph = "$htmlgraph"."$htmlgraph2";
				}
				$htmlgraph = "$htmlgraph"."---<br>$_<br>\n</font>\n</tt>\n</td>\n";
			}
		}
		$htmlgraph = "$htmlgraph"."</tr>\n</tbody>\n</table>\n</tr>\n</td>\n</tbody>\n</table>\n<br>\nKey:&nbsp;[_]&nbsp;&nbsp;=&nbsp;&nbsp;$htmldivide<br>\n";
	} else {
		$htmlgraph = "<br>\n";
	}
	
	$htmldoc = "$htmlheader"."$htmlbody"."$htmlgraph"."$htmlfooter";

	open FILE,"> $htmldumpfile" 
		or print"\nWARNING: Could Not Open $htmldumpfile \n";
	print FILE "$htmldoc"
		or print"\nWARNING: Could Not Write To $htmldumpfile \n";	
	close FILE
		or print"\nWARNING: Could Not Even Close $htmldumpfile \n";
		
}

sub printsavefile {
	findbankstkpttotal();
	#Note: saving takes into accout tax and fees for selling stocks etc
	if ($bankstkpttotal > 0) {
		$savestring = ($money + $banksavmoney + (($bankstkpttotal - ($bankstkpttotal * $stocktax)) - $stocktcstsl))."_"."$startmoney";
	} else {
		$savestring = ($money + $banksavmoney)."_"."$startmoney";
	}
	padsavestring();
	encodesavestring();
	
	open FILE,"> $savefile" 
		or print"\nWARNING: Could Not Open $savefile \n";
	print FILE "$savestring"
		or print"\nWARNING: Could Not Write To $savefile \n";	
	close FILE
		or print"\nWARNING: Could Not Even Close $savefile \n";
}

sub padsavestring {
	$buff0 = length($savestring);
	$savestring = "$savestring"."_"."$buff0"."\n";
	$buff0 = '';
}

sub zerosavefile {
	findbankstkpttotal();
	$savestring = '0_'."$startmoney";
	padsavestring();
	encodesavestring();
	
	open FILE,"> $savefile" 
		or print"\nWARNING: Could Not Open $savefile \n";
	print FILE "$savestring"
		or print"\nWARNING: Could Not Write To $savefile \n";	
	close FILE
		or print"\nWARNING: Could Not Even Close $savefile \n";
}

sub zeroaccounts {
	$fundretailshares = 0;
	$fundindustryshares = 0;
	$fundtechshares = 0;
	$fundenergyshares = 0;
	$fundtextileshares = 0;
	$fundinvestmentshares = 0;
	$fundlendingshares = 0;
	$fundconstructionshares = 0;
	$fundminingshares = 0;
	$fundindexshares = 0;
	$loadedsavefile = 0;
		
	$banksavintrst = 0; #This period's interest
	$banksavmoney = 0; #The acctual account
	$banksavsprncpletrk = 0; #Tracks all deposits over the life of the account
	$banksavswthdrwtrk = 0; #Tracks all withdrawals over the life of the account
	$banksavsprncple = 0; #Current Deposited Principle
	$banksavecrintsttrk = 0; #Tracks Current Intrest (total - principle)
	$banksavintrsttrk = 0; #Tracks the total earned interest over the life of the account
	$bankdepst = 0;
	$bankwtdrl = 0;
	$bankstkbuy = 0;
	$bankstksell = 0;
	$bankstkpttotal = 0;
	$bankfndmorinfo = 0;
}

sub encodesavestring {
	$savestring =~ s/\./t/g;
	$savestring =~ s/\+/y/g;
	$savestring =~ s/e/r/g;
	$savestring =~ s/0/a/g;
	$savestring =~ s/2/c/g;
	$savestring =~ s/4/e/g;
	$savestring =~ s/1/g/g;
	$savestring =~ s/6/i/g;
	$savestring =~ s/3/k/g;
	$savestring =~ s/5/m/g;
	$savestring =~ s/8/o/g;
	$savestring =~ s/9/q/g;
	$savestring =~ s/7/s/g;
	$savestring =~ s/_/u/g;
}

sub decodesavestring {
	$savestring =~ s/a/0/g;
	$savestring =~ s/c/2/g;
	$savestring =~ s/e/4/g;
	$savestring =~ s/g/1/g;
	$savestring =~ s/i/6/g;
	$savestring =~ s/k/3/g;
	$savestring =~ s/m/5/g;
	$savestring =~ s/o/8/g;
	$savestring =~ s/q/9/g;
	$savestring =~ s/s/7/g;
	$savestring =~ s/u/_/g;
	$savestring =~ s/r/e/g;
	$savestring =~ s/y/\+/g;
	$savestring =~ s/t/\./g;
}

sub loadsavefile {	
	$savestring = "";
	open FILE,"< $savefile" 
	  or $fail = 1;
	if ($fail == 0) {
	    while ($line = <FILE>) {
		chomp($line);
		$savestring = "$savestring"."$line";
	    }
	}
	close FILE
	  or $fail = 1;
	
	chomp($savestring);
	decodesavestring();
	#print"$savestring"."\n";
	$savestring =~ s/\W!\.//g;
	#print"$savestring"."\n";
	
	($buff2, $buff1, $buff0) = split(/_/,$savestring, 3);
	#print "$buff2, $buff1, $buff0"."\n";
	
	if (length("$buff2"."_"."$buff1") == $buff0) {
		$money = $buff2;
		$startmoney = $buff1;
		#print "$savestring $money $startmoney"."\n";
		$buff0 = '';
		$buff1 = '';
		$buff2 = '';
	} else {
		print"\nWARNING: $savefile Corrupt or tampered with\n";
	}
}


sub statsmachine {
	print colored('                                                                                ',"$boldblack on_$bgcblack"); print"\n";

	print colored('                                                                                ',"$boldblack on_$bgcblack"); print"\n";

	print colored(' ___________________________________________________   ________________________ ',"$boldblack on_$bgcblack"); print"\n";

	print colored('/  ________________________________________________ \\ / _____________________  \\',"$boldblack on_$bgcblack"); print"\n";

	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                                                ',"$boldwhite on_$bgcblue");
	print colored('| | |',"$boldblack on_$bgcblack");
	print colored('          _          ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                                                ',"$boldwhite on_$bgcblue");
	print colored('| | |',"$boldblack on_$bgcblack");
	print colored('  -------[_]-------  ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('      Notice: Printing Stats Costs 20 Coins     ',"$boldwhite on_$bgcblue");
	print colored('| | |',"$boldblack on_$bgcblack");
	print colored('_____________________',"$boldwhite on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                                                ',"$boldwhite on_$bgcblue");
	print colored('| | |',"$boldblack on_$bgcblack");
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('               Press "P" To Print               ',"$boldwhite on_$bgcblue");
	print colored('| | |',"$boldblack on_$bgcblack");
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('      Press "C" To Return to Casino Menu        ',"$boldwhite on_$bgcblue");
	print colored('| | |',"$boldblack on_$bgcblack");
	print colored('_____________________',"$boldwhite on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                                                ',"$boldwhite on_$bgcblue");
	print colored('| | |',"$boldblack on_$bgcblack");
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                                                ',"$boldwhite on_$bgcblue");
	print colored('| | |',"$boldblack on_$bgcblack");
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                                                ',"$boldwhite on_$bgcblue");
	print colored('| | |',"$boldblack on_$bgcblack");
	print colored('_____________________',"$boldwhite on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                                                ',"$boldwhite on_$bgcblue");
	print colored('| | |',"$boldblack on_$bgcblack");
	print colored('   | ',"$boldwhite on_$bgcwhite");
	print colored('___________',"$boldblack on_$bgcwhite");
	print colored(' |   ',"$boldwhite on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                                                ',"$boldwhite on_$bgcblue");
	print colored('| | |',"$boldblack on_$bgcblack");
	print colored('   |_____________|   ',"$boldwhite on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                                                ',"$boldwhite on_$bgcblue");
	print colored('| | |',"$boldblack on_$bgcblack");
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                                                ',"$boldwhite on_$bgcblue");
	print colored('| | |',"$boldblack on_$bgcblack");
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                                                ',"$boldwhite on_$bgcblue");
	print colored('| | |',"$boldblack on_$bgcblack");
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('|  ------------------------------------------------  | |',"$boldblack on_$bgcblack"); 
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('|                           ',"$boldblack on_$bgcblack");
	print colored('CAEthaver2 Systems',"$boldblue on_$bgcblack");
	print colored('[',"$boldblack on_$bgcblack");
	print colored('|||',"$boldred on_$bgcred");
	print colored(']  ',"$boldblack on_$bgcblack");
	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('\___________________________________________________/| |',"$boldblack on_$bgcblack"); 
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('    ____________________________________________     ',"$white on_$bgcblack"); 
	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('   / [1] [2] [3] [4] [5] [6] [7] [8] [9] [0] [|]\    ',"$white on_$bgcblack"); 
	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('   |[Q] [W] [E] [R] [T] [Y] [U] [I] [O] [P] [-] |    ',"$white on_$bgcblack"); 
	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('  /[CAPS] [A] [S] [D] [F] [G] [H] [J] [K] [L] [+]\   ',"$white on_$bgcblack"); 
	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('  |[SHIFT] [Z] [X] [C] [V] [B] [N] [M] [<] [>] [?]|  ',"$white on_$bgcblack"); 
	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored(' /[CTRL] [ALT] [____________________] [ALT] [ENTER]\\ ',"$white on_$bgcblack"); 
	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored(' \\_________________________________________________/ ',"$white on_$bgcblack"); 
	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('                                                     ',"$white on_$bgcblack"); 
	print colored('\\_________________________/',"$boldblack on_$bgcblack"); print"\n";
	save2startinfo();
}

sub save2startinfo {
	$sv2startinfo = <STDIN>;
	chomp($sv2startinfo);

	if (($sv2startinfo eq 'p') or ($sv2startinfo eq 'P')) {
		if ($money >= 20) {
			$money = $money - 20;
			$moneyexp = $moneyexp + 20;
			newlines();
			if ($playtrack == 1) {
				save2setkey();
				newlines();
			}
			save2html();
			newlines();
			statsmachine();
		} else {
			newlines();
			statsmachine();		
		}		
	} elsif (($sv2startinfo eq 'exit') or ($sv2startinfo eq 'EXIT') or ($sv2startinfo eq 'quit') or ($sv2startinfo eq 'QUIT')) {
		exitgame();
	} elsif ($sv2startinfo eq "c")  {
		return;
	} elsif ($sv2startinfo eq "C")  {
		return;
	} else {
		newlines();
		statsmachine();
	}

}

sub save2setkey {
	print colored('                                                                                ',"$boldblack on_$bgcblack"); print"\n";

	print colored('                                                                                ',"$boldblack on_$bgcblack"); print"\n";

	print colored(' ___________________________________________________   ________________________ ',"$boldblack on_$bgcblack"); print"\n";

	print colored('/  ________________________________________________ \\ / _____________________  \\',"$boldblack on_$bgcblack"); print"\n";

	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                                                ',"$boldwhite on_$bgcblue");
	print colored('| | |',"$boldblack on_$bgcblack");
	print colored('          _          ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                                                ',"$boldwhite on_$bgcblue");
	print colored('| | |',"$boldblack on_$bgcblack");
	print colored('  -------[_]-------  ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('  Enter Key Value For Game Progress Graph       ',"$boldwhite on_$bgcblue");
	print colored('| | |',"$boldblack on_$bgcblack");
	print colored('_____________________',"$boldwhite on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                                                ',"$boldwhite on_$bgcblue");
	print colored('| | |',"$boldblack on_$bgcblack");
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                                                ',"$boldwhite on_$bgcblue");
	print colored('| | |',"$boldblack on_$bgcblack");
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                                                ',"$boldwhite on_$bgcblue");
	print colored('| | |',"$boldblack on_$bgcblack");
	print colored('_____________________',"$boldwhite on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                                                ',"$boldwhite on_$bgcblue");
	print colored('| | |',"$boldblack on_$bgcblack");
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                                                ',"$boldwhite on_$bgcblue");
	print colored('| | |',"$boldblack on_$bgcblack");
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                                                ',"$boldwhite on_$bgcblue");
	print colored('| | |',"$boldblack on_$bgcblack");
	print colored('_____________________',"$boldwhite on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                                                ',"$boldwhite on_$bgcblue");
	print colored('| | |',"$boldblack on_$bgcblack");
	print colored('   | ',"$boldwhite on_$bgcwhite");
	print colored('___________',"$boldblack on_$bgcwhite");
	print colored(' |   ',"$boldwhite on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                                                ',"$boldwhite on_$bgcblue");
	print colored('| | |',"$boldblack on_$bgcblack");
	print colored('   |_____________|   ',"$boldwhite on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                                                ',"$boldwhite on_$bgcblue");
	print colored('| | |',"$boldblack on_$bgcblack");
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                                                ',"$boldwhite on_$bgcblue");
	print colored('| | |',"$boldblack on_$bgcblack");
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                                                ',"$boldwhite on_$bgcblue");
	print colored('| | |',"$boldblack on_$bgcblack");
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('|  ------------------------------------------------  | |',"$boldblack on_$bgcblack"); 
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('|                           ',"$boldblack on_$bgcblack");
	print colored('CAEthaver2 Systems',"$boldblue on_$bgcblack");
	print colored('[',"$boldblack on_$bgcblack");
	print colored('|||',"$boldred on_$bgcred");
	print colored(']  ',"$boldblack on_$bgcblack");
	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('\___________________________________________________/| |',"$boldblack on_$bgcblack"); 
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('    ____________________________________________     ',"$white on_$bgcblack"); 
	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('   / [1] [2] [3] [4] [5] [6] [7] [8] [9] [0] [|]\    ',"$white on_$bgcblack"); 
	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('   |[Q] [W] [E] [R] [T] [Y] [U] [I] [O] [P] [-] |    ',"$white on_$bgcblack"); 
	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('  /[CAPS] [A] [S] [D] [F] [G] [H] [J] [K] [L] [+]\   ',"$white on_$bgcblack"); 
	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('  |[SHIFT] [Z] [X] [C] [V] [B] [N] [M] [<] [>] [?]|  ',"$white on_$bgcblack"); 
	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";


	print colored(' /[CTRL] [ALT] [____________________] [ALT] [ENTER]\\ ',"$white on_$bgcblack"); 
	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored(' \\_________________________________________________/ ',"$white on_$bgcblack"); 
	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('                                                     ',"$white on_$bgcblack"); 
	print colored('\\_________________________/',"$boldblack on_$bgcblack"); print"\n";
	
	print color "reset";
	print"enter key value [$htmldivide]: ";
	
	$buff0 = <STDIN>;
	chomp($buff0);
	$buff0 =~ s/\D//g;
	if ($buff0 ne '') {
		$htmldivide = $buff0;
	}	
}

sub save2html {
	print colored('                                                                                ',"$boldblack on_$bgcblack"); print"\n";

	print colored('                                                                                ',"$boldblack on_$bgcblack"); print"\n";

	print colored(' ___________________________________________________   ________________________ ',"$boldblack on_$bgcblack"); print"\n";

	print colored('/  ________________________________________________ \\ / _____________________  \\',"$boldblack on_$bgcblack"); print"\n";

	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                                                ',"$boldwhite on_$bgcblue");
	print colored('| | |',"$boldblack on_$bgcblack");
	print colored('          _          ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                                                ',"$boldwhite on_$bgcblue");
	print colored('| | |',"$boldblack on_$bgcblack");
	print colored('  -------[_]-------  ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('  Notice: Stats Will Now Be Printed To A File   ',"$boldwhite on_$bgcblue");
	print colored('| | |',"$boldblack on_$bgcblack");
	print colored('_____________________',"$boldwhite on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                                                ',"$boldwhite on_$bgcblue");
	print colored('| | |',"$boldblack on_$bgcblack");
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('  Enter Filename (gpcs2-st.html Is The Default) ',"$boldwhite on_$bgcblue");
	print colored('| | |',"$boldblack on_$bgcblack");
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                                                ',"$boldwhite on_$bgcblue");
	print colored('| | |',"$boldblack on_$bgcblack");
	print colored('_____________________',"$boldwhite on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                                                ',"$boldwhite on_$bgcblue");
	print colored('| | |',"$boldblack on_$bgcblack");
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                                                ',"$boldwhite on_$bgcblue");
	print colored('| | |',"$boldblack on_$bgcblack");
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                                                ',"$boldwhite on_$bgcblue");
	print colored('| | |',"$boldblack on_$bgcblack");
	print colored('_____________________',"$boldwhite on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                                                ',"$boldwhite on_$bgcblue");
	print colored('| | |',"$boldblack on_$bgcblack");
	print colored('   | ',"$boldwhite on_$bgcwhite");
	print colored('___________',"$boldblack on_$bgcwhite");
	print colored(' |   ',"$boldwhite on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                                                ',"$boldwhite on_$bgcblue");
	print colored('| | |',"$boldblack on_$bgcblack");
	print colored('   |_____________|   ',"$boldwhite on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                                                ',"$boldwhite on_$bgcblue");
	print colored('| | |',"$boldblack on_$bgcblack");
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                                                ',"$boldwhite on_$bgcblue");
	print colored('| | |',"$boldblack on_$bgcblack");
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                                                ',"$boldwhite on_$bgcblue");
	print colored('| | |',"$boldblack on_$bgcblack");
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('|  ------------------------------------------------  | |',"$boldblack on_$bgcblack"); 
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('|                           ',"$boldblack on_$bgcblack");
	print colored('CAEthaver2 Systems',"$boldblue on_$bgcblack");
	print colored('[',"$boldblack on_$bgcblack");
	print colored('|||',"$boldred on_$bgcred");
	print colored(']  ',"$boldblack on_$bgcblack");
	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('\___________________________________________________/| |',"$boldblack on_$bgcblack"); 
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('    ____________________________________________     ',"$white on_$bgcblack"); 
	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('   / [1] [2] [3] [4] [5] [6] [7] [8] [9] [0] [|]\    ',"$white on_$bgcblack"); 
	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('   |[Q] [W] [E] [R] [T] [Y] [U] [I] [O] [P] [-] |    ',"$white on_$bgcblack"); 
	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('  /[CAPS] [A] [S] [D] [F] [G] [H] [J] [K] [L] [+]\   ',"$white on_$bgcblack"); 
	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('  |[SHIFT] [Z] [X] [C] [V] [B] [N] [M] [<] [>] [?]|  ',"$white on_$bgcblack"); 
	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";


	print colored(' /[CTRL] [ALT] [____________________] [ALT] [ENTER]\\ ',"$white on_$bgcblack"); 
	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored(' \\_________________________________________________/ ',"$white on_$bgcblack"); 
	print colored('| |',"$boldblack on_$bgcblack"); 
	print colored('                     ',"$black on_$bgcwhite");
	print colored('| |',"$boldblack on_$bgcblack"); print"\n";

	print colored('                                                     ',"$white on_$bgcblack"); 
	print colored('\\_________________________/',"$boldblack on_$bgcblack"); print"\n";
	
	print color "reset";
	print'enter filename [gpcs2-st.html]: ';
	
	$htmlsave = <STDIN>;
	chomp($htmlsave);
	if ($htmlsave eq "") {
		$htmldumpfile = 'gpcs2-st.html';
	} else {
		$htmlsave =~ s/\./__________THISISAPERIOD__________/g;
		$htmlsave =~ s/\W//g;
		$htmlsave =~ s/__________THISISAPERIOD__________/\./g;
		$htmldumpfile = $htmlsave;
	}
	
	print2html();
	newlines();
}

sub winlosecalc {
	$winstat = ($hrstwin + $ddstwin + $ngemstwin + $ssstwin + $rrstwin + $lvrstwin + $rllvrstwin + $sbtstwin + $ccrapsstwin);
	$losestat = ($hrstlose + $ddstlose + $ngemstlose + $ssstlose + $rrstlose + $lvrstlose + $rllvrstlose + $sbtstlose + $ccrapsstlose);
}

sub moneyclock {
	$totalmc = ($hrstmc + $ddstmc + $ngemstmc + $ssstmc + $rrstmc + $lvrstmc + $rllvrstmc + $sbtstmc + $ccrapsstmc);
}

sub killmusic {
	if ($music == 1) {
		$music = 0;
		kill 9, $mkillpid;
		system("killall -9 $musicplayer > /dev/null");
		smallpause();
		waitpid($mkillpid, 0);
	}
}

sub exitgame {
	killmusic();
	if (($loadedsavefile == 1) && ($allowsave == 1)) {
		printsavefile();
	}
	newlines();
	print colored('                                                                                ',"$boldblue on_$bgcwhite"); print"\n"; 
	print colored('                                                                                ',"$boldblue on_$bgcwhite"); print"\n"; 
	print colored('                                                                                ',"$boldblue on_$bgcwhite"); print"\n"; 
	print colored("                  Thank  You  For  Playing  GPCSlots 2  v$version                  ","$boldblue on_$bgcwhite"); print"\n"; 
	print colored('                                                                                ',"$boldblue on_$bgcwhite"); print"\n"; 
	print colored('                                                                                ',"$boldblue on_$bgcwhite"); print"\n"; 
	print colored('       Author: MikeeUSA                                                         ',"$boldblue on_$bgcwhite"); print"\n"; 
	print colored('                                                                                ',"$boldblue on_$bgcwhite"); print"\n"; 
	print colored('     Web Site: https://cat2.dynu.ca  or  https://caethaver2.dynu.ca             ',"$boldblue on_$bgcwhite"); print"\n"; 
	print colored('                                                                                ',"$boldblue on_$bgcwhite"); print"\n"; 
	print colored('  IRC Channel: #linux  on  cat2.dynu.ca                                         ',"$boldblue on_$bgcwhite"); print"\n"; 
	print colored('                                                                                ',"$boldblue on_$bgcwhite"); print"\n"; 
	print colored('    Web Forum: https://cat2.dynu.ca/bb  or  https://caethaver2.dynu.ca/bb       ',"$boldblue on_$bgcwhite"); print"\n"; 
	print colored('                                                                                ',"$boldblue on_$bgcwhite"); print"\n"; 
	print colored('                                                                                ',"$boldblue on_$bgcwhite"); print"\n"; 
	print colored('                                                                                ',"$boldblue on_$bgcwhite"); print"\n"; 
	print colored('        Get The Newest Version At https://cat2.dynu.ca/cat2/gpcs2.html          ',"$boldblue on_$bgcwhite"); print"\n"; 
	print colored('               Or At https://caethaver2.dynu.ca/cat2/gpcs2.html                 ',"$boldblue on_$bgcwhite"); print"\n"; 
	print colored('                                                                                ',"$boldblue on_$bgcwhite"); print"\n"; 
	print colored('                                                                                ',"$boldblue on_$bgcwhite"); print"\n"; 
	print colored('                                                                                ',"$boldblue on_$bgcwhite"); print"\n"; 
	print colored('                                                                                ',"$boldblue on_$bgcwhite"); print"\n"; 
	print colored('                                                                                ',"$boldblue on_$bgcwhite"); print"\n"; 
	print colored('                                                                                ',"$boldblue on_$bgcwhite"); print"\n"; 
	print colored('                                                                                ',"$boldblue on_$bgcwhite"); print"\n"; 
	print colored('                                                                                ',"$boldblue on_$bgcwhite"); print"\n"; 
	print colored('                                                                                ',"$boldblue on_$bgcwhite"); print"\n"; 
	print colored('                                  CAEthaver2                                    ',"$boldblue on_$bgcwhite"); print"\n"; 
	print colored('                                                                                ',"$boldblue on_$bgcwhite"); print"\n"; 
	exit();
}

#GPCSLOTS 2 by MikeeUSA
#https://cat2.dynu.ca  or  https://caethaver2.dynu.ca
#Feminism Delenda Est.
