=head1 NAME

Linux::DVB - interface to (some parts of) the Linux DVB API

=head1 SYNOPSIS

 use Linux::DVB;

=head1 DESCRIPTION

This module provides an interface to the Linux DVB API. It is a straightforward
translation of the C API. You should read the Linux DVB API description to make
any sense of this module. It can be found here:

   http://www.linuxtv.org/developer/dvbapi.xml

All constants from F<frontend.h> and F<demux.h> are exported by their C
name and by default.

Noteworthy differences to the C API: unions and sub-structs are usually
translated into flat perl hashes, i.e C<struct.u.qam.symbol_rate>
becomes C<< $struct->{symbol_rate} >>.

Noteworthy limitations of this module include: no way to set the
frequency or diseqc. No interface to the video, audio and net devices.
If you need this functionality bug the author.

=cut

package Linux::DVB;

use Fcntl ();

BEGIN {
   $VERSION = '0.02';
   @ISA = qw(Exporter);

   require XSLoader;
   XSLoader::load __PACKAGE__, $VERSION;

   require Exporter;

   my %consts = &_consts;
   my $consts;
   while (my ($k, $v) = each %consts) {
      push @EXPORT, $k;
      $consts .= "sub $k(){$v}\n";
   }
   eval $consts;
}

sub new {
   my ($class, $path, $mode) = @_;

   my $self = bless { path => $path, mode => $mode }, $class;
   sysopen $self->{fh}, $path, $mode | &Fcntl::O_NONBLOCK
      or die "$path: $!";
   $self->{fd} = fileno $self->{fh};

   $self;
}

sub fh { $_[0]{fh} }
sub fd { $_[0]{fd} }

sub blocking {
   fcntl $_[0]{fh}, &Fcntl::F_SETFL, $_[1] ? 0 : &Fcntl::O_NONBLOCK;
}

package Linux::DVB::Frontend;

@ISA = qw(Linux::DVB);

=head1 Linux::DVB::Frontend CLASS

=head2 SYNOPSIS

 my $fe = new Linux::DVB::Frontend $path, $writable;

 my $fe = new Linux::DVB::Frontend
             "/dev/dvb/adapter0/frontend0", 1;

 $fe->fh; # filehandle
 $fe->fd; # fileno
 $fe->blocking (0); # or 1

 $fe->{name}
 $fe->{type}
 $fe->frontend_info->{name}

 $fe->status & FE_HAS_LOCK
 print $fe->ber, $fe->snr, $fe->signal_strength, $fe->uncorrected;

 my $tune = $fe->parameters;
 $tune->{frequency};
 $tune->{symbol_rate};

=cut

sub new {
   my ($class, $path, $mode) = @_;
   my $self = $class->SUPER::new ($path, $mode ? &Fcntl::O_RDWR : &Fcntl::O_RDONLY);

   %$self = ( %$self, %{ $self->frontend_info } );
   
   $self;
}

sub frontend_info   { _frontend_info   ($_[0]{fd}) }
sub status          { _read_status     ($_[0]{fd}) }
sub ber             { _read_ber        ($_[0]{fd}) }
sub snr             { _snr             ($_[0]{fd}) }
sub signal_strength { _signal_strength ($_[0]{fd}) }
sub uncorrected     { _uncorrected     ($_[0]{fd}) }

#sub set             { _set   ($_[0]{fd}, $_[0]{type}) }
sub parameters      { _get   ($_[0]{fd}, $_[0]{type}) }
sub event           { _event ($_[0]{fd}, $_[0]{type}) }

package Linux::DVB::Demux;

@ISA = qw(Linux::DVB);

=head1 Linux::DVB::Demux CLASS

=head2 SYNOPSIS

 my $dmx = new Linux::DVB::Demux
             "/dev/dvb/adapter0/demux0";

 $fe->fh; # filehandle
 $fe->fd; # fileno
 $fe->blocking (1); # non-blocking is default

 $dmx->buffer (16384);
 $dmx->sct_filter ($pid, "filter", "mask", $timeout=0, $flags=DMX_CHECK_CRC);
 $dmx->pes_filter ($pid, $input, $output, $type, $flags=0);
 $dmx->start; 
 $dmx->stop; 

=cut

sub new {
   my ($class, $path) = @_;
   my $self = $class->SUPER::new ($path, &Fcntl::O_RDWR);
   
   $self;
}

sub start      { _start      ($_[0]{fd}) }
sub stop       { _stop       ($_[0]{fd}) }

sub sct_filter { _filter     ($_[0]{fd}, @_[1, 2, 3, 4, 5]) }
sub pes_filter { _pes_filter ($_[0]{fd}, @_[1, 2, 3, 4, 5]) }
sub buffer     { _buffer     ($_[0]{fd}, $_[1]) }

package Linux::DVB::Decode;

use Encode;

sub text($) {
   for ($_[0]) {
      s/^([\x01-\x0b])// and $_ = decode sprintf ("iso-8859-%d", 4 + ord $1), $_;
      # 10 - pardon you???
      s/^\x11// and $_ = decode "utf16-be", $_;
      # 12 ksc5601, DB
      # 13 db2312, DB
      # 14 big5(?), DB
      s/\x8a/\n/g;
      #s/([\x00-\x09\x0b-\x1f\x80-\x9f])/sprintf "{%02x}", ord $1/ge;
      s/([\x00-\x09\x0b-\x1f\x80-\x9f])//ge;
   }
}

1;

=head1 AUTHOR

 Marc Lehmann <schmorp@schmorp.de>
 http://home.schmorp.de/

=cut

