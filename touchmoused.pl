#!/usr/bin/perl

use IO::Select;
use IO::Socket;
use IO::Handle; # Needed for autoflush
use Fcntl; # Needed for sysopen flags (?)
use Switch;
use POSIX ":sys_wait_h";
require "sys/ioctl.ph";

use constant {
	UI_DEV_CREATE => 0x5501,
	UI_DEV_DESTROY => 0x5502,
	
	UI_SET_EVBIT => 0x40045564,
	UI_SET_KEYBIT => 0x40045565,
	UI_SET_RELBIT => 0x40045566,
	UI_SET_ABSBIT => 0x40045567,

	EV_SYN => 0x00,
	EV_KEY => 0x01,
	EV_REL => 0x02,
	EV_ABS => 0x03,

	REL_X => 0x00,
	REL_Y => 0x01,

	REL_HWHEEL => 0x06,
	
	REL_WHEEL => 0x08,

	ABS_X => 0x00,
	ABS_Y => 0x01,

	BUS_VIRTUAL => 0x06,

	BTN_MOUSE => 0x110,
	BTN_TOUCH => 0x14a,
	BTN_TOOL_FINGER => 0x145,

	SYN_REPORT => 0,
};

my %keymap = (
	ord('1') => 2,
	ord('2') => 3,
	ord('3') => 4,
	ord('4') => 5,
	ord('5') => 6,
	ord('6') => 7,
	ord('7') => 8,
	ord('8') => 9,
	ord('9') => 10,
	ord('0') => 11,
	ord('-') => 12,
	ord('=') => 13,

	ord('q') => 16,
	ord('w') => 17,
	ord('e') => 18,
	ord('r') => 19,
	ord('t') => 20,
	ord('y') => 21,
	ord('u') => 22,
	ord('i') => 23,
	ord('o') => 24,
	ord('p') => 25,

	91 => 26, # [
	93 => 27, # ]
	10 => 28, # Enter

	ord('a') => 30,
	ord('s') => 31,
	ord('d') => 32,
	ord('f') => 33,
	ord('g') => 34,
	ord('h') => 35,
	ord('j') => 36,
	ord('k') => 37,
	ord('l') => 38,
	59 => 39, # ;
	39 => 40, # '
	92 => 43, # \
	
	ord('z') => 44,
	ord('x') => 45,
	ord('c') => 46,
	ord('v') => 47,
	ord('b') => 48,
	ord('n') => 49,
	ord('m') => 50,
	44 => 51, # ,
	46 => 52, # .
	47 => 53, # /
	
	55 => 55, # * (Emulates keypad asterisk)

	32 => 57, # Space
);

my %modmap = ( # Map for modifier keys
	51 => 14, # Backspace
	59 => 29, # Ctrl (emulates left ctrl)
	58 => 56, # Alt (emulates left alt)
	55 => 125, # Win (emulates left meta)
	"shift" => 42, # Shift key, never send
);

my %mousemap = ( # Map for mouse buttons
	256 => 0x110, # BTN_LEFT
	257 => 0x111, # BTN_RIGHT
	258 => 0x112, # BTN_MIDDLE
);

my $name = `hostname`;
my %conns;
my $ui; # /dev/uinput handle

my $strpk_uinput_dev = "a80SSSSiI256";
my $strpk_input_event = "LLSSI";

sub send_ev {
	print $ui pack($strpk_input_event, 0, 0, shift, shift, shift);
}

sub send_key {
	my $ord = shift;
	my $uc = 0;

	if ($ord >= ord("A") && $ord <= ord("Z")) {
		$uc = true;
		$ord = $ord + (ord("a") - ord("A"));
	}

	if ($keymap{$ord}) {
		$uc && send_mod('shift', 1);
		send_ev(EV_KEY, $keymap{$ord}, 1);
		send_ev(EV_KEY, $keymap{$ord}, 0);
		$uc && send_mod('shift', 0);
	}

}

sub send_mod {
	my $code = shift;

	if ($modmap{$code}) {
		send_ev(EV_KEY, $modmap{$code}, shift);
	}
}

sub send_mouse_button {
	my $btn = shift;

	if ($mousemap{$btn}) {
		send_ev(EV_KEY, $mousemap{$btn}, shift);
	}
}

chomp $name;

my $avahi_publish = fork();
if ($avahi_publish==0) {
	exec 'avahi-publish-service',
		$name,
		"_iTouch._tcp",
		"4026";
}

sub REAP {
    if ($avahi_publish == waitpid(-1, WNOHANG)) {
        die("Avahi publishing failed!");
    }
    printf("***CHILD EXITED***\n");
    $SIG{CHLD} = \&REAP;
};
$SIG{CHLD} = \&REAP;

sysopen($ui, '/dev/uinput', O_NONBLOCK|O_WRONLY) || die "Can't open /dev/uinput: $!"; 
$ui->autoflush(1);

# timeval
# __kernel_time_t tv_sec (int)
# __kernel_suseconds_t tv_usec (int)


my $ret;
$ret = ioctl($ui, UI_SET_EVBIT, EV_KEY) || -1;
print "UI_SET_EVBIT EV_KEY: $ret\n";

for my $key ( values %keymap ) {
	$ret = ioctl($ui, UI_SET_KEYBIT, $key) || -1;
	print "UI_SET_KEYBIT $key: $ret\n";
}

for my $key ( values %modmap ) {
	$ret = ioctl($ui, UI_SET_KEYBIT, $key) || -1;
	print "UI_SET_KEYBIT $key: $ret\n";
}

for my $btn ( values %mousemap ) {
	$ret = ioctl($ui, UI_SET_KEYBIT, $btn) || -1;
	print "UI_SET_KEYBIT $btn: $ret\n";
}

$ret = ioctl($ui, UI_SET_EVBIT, EV_REL) || -1;
print "UI_SET_EVBIT EV_REL: $ret\n";

$ret = ioctl($ui, UI_SET_RELBIT, REL_X) || -1;
print "UI_SET_RELBIT REL_X: $ret\n";

$ret = ioctl($ui, UI_SET_RELBIT, REL_Y) || -1;
print "UI_SET_RELBIT REL_Y: $ret\n";

$ret = ioctl($ui, UI_SET_RELBIT, REL_WHEEL) || -1;
$ret = ioctl($ui, UI_SET_RELBIT, REL_HWHEEL) || -1;

$ret = ioctl($ui, UI_SET_EVBIT, EV_SYN) || -1;
print "UI_SET_EVBIT EV_SYN: $ret\n";

my @abs;
foreach (1..256) {
	# We're not using absolute mouse-events
	push(@abs, 0x00);
}

print $ui pack($strpk_uinput_dev, "TouchMouse", BUS_VIRTUAL, 0x1234, 0xfedc, 1, 0, @abs);

$ret = ioctl($ui, UI_DEV_CREATE, 0) || -1;
print "UI_DEV_CREATE: $ret \n";
if (-1 == $ret) {
	die("device creation failed");
}

my $listen = new IO::Socket::INET(Listen => 1,
	LocalPort => 4026,
	ReuseAddr => 1,
	Proto => 'tcp') or die "Can't listen on port 4026: $!";

my $sel = new IO::Select($listen);

print "listening...\n";

my $udp;

while (1) {
	my @waiting = $sel->can_read;
	foreach $fh (@waiting) {
		if ($fh==$listen) {
			my $new = $listen->accept;
			printf "new connection from %s\n", $new->sockhost;

			$sel->add($new);
			$new->blocking(0);
			$conns{$new} = {fh => $fh};


			$udp = fork();
			if (0 == $udp) {
				my $sock = IO::Socket::INET->new(LocalPort => 4026, Proto => 'udp') or die ("Couldn't create UDP socket: $!");

				print "Creating UDP socket\n";
				my $message;
				
				while ($sock->recv($message, 1024)) {
					#printf "UDP Received: %s\n", unpack("H*", $message);
					
					my($type, $value, $other) = unpack("NNN", $message);
					#printf "$type $value $other\n";
					
					switch ($type) {
						# Modifier key up
						case 1 {
							send_mod($value, 0);
						}

						# Modifier key down
						case 2 {
							send_mod($value, 1);
						}

						# Touch up
						case 4 {
							send_mouse_button($value, 0);
						}

						# Touch down
						case 5 {
							send_mouse_button($value, 1);
						}

						# Mouse horizontal
						case 6 {
							if (0 != $value) {
								print $ui pack($strpk_input_event, 0, 0, EV_REL, REL_X, $value);
							}
						}

						# Mouse vertical
						case 7 {
							if (0 != $value) {
								print $ui pack($strpk_input_event, 0, 0, EV_REL, REL_Y, $value);
							}
						}

						# Scroll vertical
						case 10 {
							$value = unpack("l", pack("L", $value));
							$value = $value * -1;
							$value = unpack("L", pack("l", $value));
							send_ev(EV_REL, REL_WHEEL, $value);
						}

						# Keypress
						case 13 {
							send_key($value);
						}

						# Scroll horizontal
						case 14 {
							send_ev(EV_REL, REL_HWHEEL, $value);
						}

						else {
							print "Undefined case:\n";
							print "Type: $type; value: $value\n";
						}
					}

					# Send sync event
					print $ui pack($strpk_input_event, 0, 0, EV_SYN, 0, 0);
				}
				print "UDP receive ended\n";
			}
		} else {
			if (eof($fh)) {
				print "closed: $fh\n";
				$sel->remove($fh);
				close $fh;
				delete $conns{$fh};
				next;
			}
			if (exists $conns{$fh}) {
				conn_handle_data($fh);
			}
		}
	}
}

# events
# LMB_D:	00000005000001000000006c2fa30ca1
# LMB_U:	00000004000001000000006c31872e21
# RMB_D:	0000000500000101000000ff189058be
# RMB_U:	0000000400000101000000ff1b671f6e
# MMB_D:	00000005000001020000012733f02ab1
# MMB_U:	0000000400000102000001281e7873b3
# a:		0000000d00000061135cbb3c08670807
# z:		0000000d0000007a135cbb5426d4951c
# A:		0000000d00000041135cbb7711e1220e
# Z:		0000000d0000005a135cbb870e57054f
# á:		0000000d000000e1135cbf511b2eb996
# ¥:		0000000d000000a5135cbfe71b89b6a9
# €:		0000000d000020ac135cc00d2483d2e6
# stip:		0000000d00002022135cc0c33b8cef0e
# BKSPC:	0000000200000033135cbf8539a7cfa8 0000000100000033135cbf8539a7cfa8
# ENTER:	0000000d0000000a135cbfb5223d4242
# CTRL_D:	000000020000003b135cbb9d27cc4369
# CTRL_U:	000000010000003b135cbbba3a1d9828
# ALT_D:	000000020000003a135cbc0c350a5a99
# ALT_U:	000000010000003a135cbc1e062af2fe
# WIN_D:	0000000200000037135cbc2e093b0597
# WIN_U:	0000000100000037135cbc3b18c2ab33
# SCR_DN:	0000000a000000030000049b062e39d0
# SCR_UP:	0000000afff.....
# SCR_L:	0000000efff.....
# SCR_R: 	0000000e000.....
# MS_DN:	        | Speed
# MS_DN:	0000000700000027000003f22d766f23
# MS_UP:		| Speed (negative number, ffffff = -1)
# MS_UP:	00000007ffffff7400000422314c55ad
# MS_L:		00000006ffffff28000004592059cd9d
# MS_R:		000000060000000100000474156be931

sub conn_handle_data {
	my $fh = shift;
	my $conn = $conns{$fh};
	
	read $fh, my $data, 16;
	printf "TCP Received: %s\n", unpack("H*", $data);
}
