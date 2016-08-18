package Utilities::Fargs;
use strict;
use Utilities qw/:all/;
#use POSIX;
use POSIX ':sys_wait_h';
use Data::Dumper;

require Exporter;

use vars qw/@EXPORT_OK @ISA/;

push @ISA, 'Exporter';

sub new
{
    my( $class, $args ) = @_;
    my $self = bless {}, $class;
    $self->command( $args->{ command } );
    $self->n( $args->{ n } );
    $self->input( $args->{ input } );
    $self->poll_interval( $args->{ poll_interval } || 1 );
    $self->m_at_a_time( $args->{ m_at_a_time } || 1 );
    $self->distribute_jobs( $args->{ distribute_jobs } || 0 );

    return $self;
}

sub command
{
    $_[1] .= " {}" unless( ( not defined $_[1] ) || ref( $_[1] ) eq 'CODE' || $_[1] =~ /{}/ );
    $_[0]->{ command } = $_[1] if @_ > 1;
    $_[0]->{ command };
}

sub m_at_a_time
{
    $_[0]->{ m_at_a_time } = $_[1] if @_ > 1;
    $_[0]->{ m_at_a_time };
}

sub distribute_jobs
{
    $_[0]->{ distribute_jobs } = $_[1] if @_ > 1;
    $_[0]->{ distribute_jobs };
}

sub n
{
    $_[0]->{ n } = $_[1] if @_ > 1;
    $_[0]->{ n };
}

sub poll_interval
{
    $_[0]->{ poll_interval } = $_[1] if @_ > 1;
    $_[0]->{ poll_interval };
}

sub input
{
    if( @_ > 1 )
    {
	if( @_ == 2 )
	{
	    if( ( ref( $_[1] ) eq 'ARRAY' ) || ( UNIVERSAL::isa( $_[1], 'IO::Handle' ) ) )
	    {
		$_[0]->{ input } = $_[1];
	    }
	    else
	    {
		$_[0]->{ input } = [ $_[1] ];
	    }
	}
	else
	{
	    $_[0]->{ input } = [ @_[1, $#_] ];
	}
    }
    $_[0]->{ input };
}

sub run
{
    my( $self ) = @_;

    my( $command, $n, $input );
    die "No command defined\n"                          unless defined ( $command = $self->command() );
    die "N procs not defined or meaningless\n"          unless ( defined ( $n = $self->n() ) && ( $n =~ /^\d+$/ ) && ( $n > 0 ) );
    die "No inputs defined\n"                           unless defined ( $input = $self->input() );
    die "Input must either by an array or a filehandle" unless ( ref( $input ) eq 'ARRAY' || UNIVERSAL::isa( $input, 'IO::Handle' ) );

    if( UNIVERSAL::isa( $input, 'IO::Handle' ) )
    {
	my $fh = $input;
	$input = [];
	while( $_ = $fh->getline() )
	{
	    chomp;
	    push @$input, $_;
	}
	$fh->close;
	$self->input( $input );
    }
    if( $self->distribute_jobs )
    {
	$self->m_at_a_time( POSIX::ceil( @$input / $self->n() ) );
    }
    $self->_run_commands();
    return $self->_get_stats();
}

sub _run_commands
{
    my( $self )       = @_;
    my $procs_running = 0;
    my $max_procs     = $self->n();
    my $all_input         = $self->input();
    my $command       = $self->command();

    $self->_clear_stats();
    $self->_started();

    while( @$all_input > 0 or $procs_running > 0 )
    {
	if( $procs_running < $max_procs and @$all_input > 0 )
	{
	    my $input = [splice( @$all_input, 0, $self->m_at_a_time() ) ];
	    if( my $pid = fork() )
	    {
		$self->_pid_started( $pid );
		$self->_pid_command( $pid, join( ' ', @$input ) );
		$procs_running++;
	    }
	    elsif( $pid == 0 )
	    {
		if( ref( $command ) eq 'CODE' )
		{
		    $command->( @$input );
		    exit;
		}
		my $_input = join( ' ', @$input );
		( my $_command = $command ) =~ s/{}/$_input/g;
		exec $_command;
		die "exec failed:$!\n";
	    }
	    else
	    {
		die "Fork failed:$!\n";
	    }
	}
	else
	{
	    sleep $self->poll_interval();
	}
	while( ( my $pid = waitpid( -1, WNOHANG ) ) > 0 )
	{
	    $procs_running--;
	    $self->_pid_ended( $pid );
	    $self->_pid_status( $pid, $? );
	}
    }
    $self->_ended();
}

sub _clear_stats
{
    my( $self ) = @_;
    for( qw/ _start _end _pid_start _pid_end _pid_status _pid_command _fails / )
    {
	$self->{ $_ } = undef;
    }
}

sub _started
{
    $_[0]->{ _start } = [localtime];
}

sub _ended
{
    $_[0]->{ _end } = [localtime];
}

sub _pid_started
{
    $_[0]->{ _pid_start }{ $_[1] } = [localtime]; }

sub _pid_ended
{
    $_[0]->{ _pid_end }{ $_[1] } = [localtime]; }

sub _pid_status
{
    $_[0]->{ _pid_status }{ $_[1] } = $_[2];
    $_[0]->_proc_failed() if $_[2];
}

sub _pid_command
{
    $_[0]->{ _pid_command }{ $_[1] } = $_[2]; }

sub _fails
{
    $_[0]->{ _fails } ||= 0;
    $_[0]->{ _fails };
}

sub _proc_failed
{
    $_[0]->{ _fails } ||= 0;
    $_[0]->{ _fails }++;
}

sub _get_stats
{
    my( $self, $time_format ) = @_;
    $time_format ||= "%Y-%m-%d %H:%M:%S";

    my %command_stats;

    foreach my $pid ( keys %{ $self->{ _pid_start } } )
    {
	my $stat = $self->{ _pid_status }{ $pid };
	push @{ $command_stats{ $self->{ _pid_command }{ $pid } } }, { start  => $time_format eq 'none' ?
									   $self->{ _pid_start  }{ $pid } :
									   POSIX::strftime( $time_format, @{ $self->{ _pid_start  }{ $pid } } ),
								       end    => $time_format eq 'none' ?
									   $self->{ _pid_end  }{ $pid } :
									   POSIX::strftime( $time_format, @{ $self->{ _pid_end  }{ $pid } } ),
								       exit_code => WIFEXITED( $stat ) ? WEXITSTATUS( $stat ) : 0,
								       signal    => WIFSTOPPED( $stat ) ? WSTOPSIG( $stat ) : 0,
								       };
    }
    my $start_time = $time_format eq 'none' ? $self->{ _start  } : POSIX::strftime( $time_format, @{ $self->{ _start  } } );
    my $end_time =   $time_format eq 'none' ? $self->{ _end  }   : POSIX::strftime( $time_format, @{ $self->{ _end  } } );
    
    return { startime => $start_time,
	     endtime  => $end_time,
	     args     => \%command_stats,
	     fails    => $self->_fails(),
	     command  => $self->command(),
	 };
}

# Convenience routine to report stats returned from run_commands.

sub report_stats
{
    my( $stats ) = @_;
    print "Command: $stats->{ command }\n";
    print "Startime: $stats->{ startime }\n";
    print "Endtime: $stats->{ endtime }\n";
    print "Number failed: $stats->{ fails }\n";
    print "Detail: \n";
    printf( "%-80s %5s%4s%-23s%-23s\n", "Arguments", "EXIT", "SIG", "    START", "    END" );
    print '-'x136, "\n";
    while( my( $arg, $all_statuses ) = each %{ $stats->{ args } } )
    {
	if( ref( $arg ) eq 'ARRAY' )
	{
	    $arg = join( ' ', @$arg );
	}
	foreach my $status ( @$all_statuses )
	{
	    printf( "%-80s %5d%4d%23s%23s\n", $arg, @$status{ qw/exit_code signal start end/ } );
	}
    }
}


1;

__END__

=pod

=head1 NAME

Utilities::Fargs -- run many jobs at once.

=head1 SYNOPSIS

  use Utilities::Fargs;
  my $max_procs = 20;
  my $base_command = join( ' ', @ARGV );
  my $fargs = Utilities::Fargs->new( { command => $base_command,
	  			       n       => $max_procs,
				       input   => new FileHandle( "<&STDIN" ),
				    } ) or die "Unable to create new Utility::Fargs object";
  my $stats = $fargs->run();
  Utilities::Fargs::report_stats( $stats );

=head1 DESCRIPTION

Fargs is a module that can be used to run many jobs simultaneously. The jobs can either be exteral programs, or Perl code refs. You can control the number of jobs to be run at once. You can also indicate how many arguments to pass to each job, or just distribute them evenly among a fixed number of processes. See EXAMPLES below.

Here are the public functions.

sub new( $class, { arg1 => ..., arg2 => ..., } )

  Constructor function. All options are passed in hash-ref. Here are the valid options:

    command: Command to run. Can either be program to run in shell, or
             a Perl CODE ref.  In the latter case, the args are passed
             in @_.

    n:       Number of jobs to run simultaneously.

    input: Input arguments. Can either be an array ref or IO::Handle
             object (includes FileHandles.)  In the latter case, then
             entire file will be read and then the commands will be
             invoked.  This might change. The input is consumed while
             running fargs, but you can use the input() function to
             provide a new input set, and run the same command again
             with fresh args.

    poll_interval: How long to sleep when waiting for something to do (defaults to 1.)

    m_at_a_time: How many arguments to pass to each process (defaults
                 to 1.)

    distribute_jobs: Only run n jobs, and divide inputs args evenly
                     among the jobs.

Each of these arguments has a matching function that can be used to set or retrieve these variables.

sub run()

Runs the jobs. Returns a data structure containing detailed run-time information about the jobs. It is a hash ref with the following keys:

  command: name of command executed
  startime: time all jobs started
  endtime: time all jobs ended
  fails: number of jobs that failed

  args: hash ref with keys being space-delimited lists of args sent to command. Each
        value is a list of results (for when the same arg is duplicated.) Each list
        list element is a hash with the following fields:
          start: start time of job
          end: end time of job
          exit_code: process exit code (0 is success)
          signal:    signal that killed process (0 is none)

sub report_stats( $stats )
   
Kind of pretty-prints the stats structure returned from run() if you don't want to parse it yourself.

=head1 EXAMPLES

1. Run wc on all the files in the current directory. By the way, this is slower than just running 'wc *'.

  my $in= [ qx/ls -1/ ];
  chomp @$in;
  my $fargs = Utilities::Fargs->new( {
    command         => "wc {} ",        
    n               => 10,
    input           => $in,
  } ) or die "Unable to create new Utility::Fargs object";
  $fargs->run

2. Run an arbitray command on all args read from STDIN

  my $max_procs = 20;
  my $base_command = join( ' ', @ARGV );
  my $fargs = Utilities::Fargs->new( { command => $base_command,
	  			       n       => $max_procs,
				       input   => new FileHandle( "<&STDIN" ),
				    } ) or die "Unable to create new Utility::Fargs object";
  my $stats = $fargs->run();

3. Same thing, but force Fargs to run 20 processes with as many command line args as necessary to each process.

  my $max_procs = 20;
  my $base_command = join( ' ', @ARGV );
  my $fargs = Utilities::Fargs->new( { command         => $base_command,
	  			       n               => $max_procs,
				       input           => new FileHandle( "<&STDIN" ),
				       distribute_jobs => 1,
				    } ) or die "Unable to create new Utility::Fargs object";
  my $stats = $fargs->run();

4. Run as many jobs as necessary, but always run 3 args per command (except the last job, unless num_jobs%3==0)

  my $max_procs = 20;
  my $base_command = join( ' ', @ARGV );
  my $fargs = Utilities::Fargs->new( { command         => $base_command,
	  			       n               => $max_procs,
				       m_at_a_time     => 3,
				       input           => new FileHandle( "<&STDIN" ),
				    } ) or die "Unable to create new Utility::Fargs object";
  my $stats = $fargs->run();

5. Print the size of all files in /tmp. 

  $in = [ map { "/tmp/$_" } qx|ls -1 /tmp| ];
  chomp @$in;
  $fargs = Utilities::Fargs->new( {
                                     command         => sub { while($_=shift){print -s $_, "\n" } },
				     n               => 50,
				     input           => $in,
				     m_at_a_time     => 10,
				 } ) or die "Unable to create new Utility::Fargs object";

  $stats = $fargs->run();

=head1 BUGS

Stores information about each job according to its PID. If, for whatever reason, a PID is reused, then the information about he first job will be lost.

=head1 AUTHOR

Paul@McKerley.com

=cut
