#!/usr/bin/perl

use File::Basename;
use strict;

my $BIN = "$ENV{HOME}/etlsupp/bin";
my $EPV_SCRIPT = "$BIN/EPVDisplay.ksh";
my $TMP = "$ENV{HOME}/KSH_TMP_$$";
my $EPV_PAT = '\$\{VAULT::(\w+)::(\w+)::(\w+)\}';
my $HOST_NAME = qx(uname -n); chomp $HOST_NAME;
my @TMP_DIR;
my $MD5_CNT = 0;

sub md5LS {
	my @ret_;

	foreach my $glob_ (@_) {
		foreach my $p_ (glob($glob_)) {
			my $md5_ = getMD5($p_);
			push @ret_, map { "$md5_ $_" } qx(ls -ld '$p_');
		}
	}

	@ret_ = sort @ret_ if @ret_;

	return @ret_;
}

sub getDate {
        my $t_ = shift;
        my $isoFormat_ = shift;
	my $ret_;

	$ret_ = getTimeStamp($t_, $isoFormat_);
	$ret_ = substr($ret_, 0, ($isoFormat_ ? 10 : 8)) if $ret_;

	return $ret_;
}

sub getFileOwner {
        my $ret_ = undef;
        if ($_[0]) {
                my @stat_ = stat($_[0]);
                $ret_ = getpwuid($stat_[4]);
        }
        return $ret_;
}

sub between {
	my ($v_, $lower_, $upper_) = @_;

	return $v_ && $lower_ && $upper_ && $lower_ <= $v_ && $v_ <= $upper_;
}

sub getTimeFromTimeStamp {
	my $s_ = shift;
	my $t_;

	if ($s_ =~ m!^\[*(\d+)[\.\-](\d+)[\.\-](\d+)[\ T:](\d+)[\.\:](\d+)[\.\:](\d+)!) {
		$t_ = timelocal($6, $5, $4, $3, $2-1, $1);
	}
	return $t_;
}

sub getTimeStamp {
        my $t_ = shift;
        my $isoFormat_ = shift;
        my $format_ = ($isoFormat_ ? "%04d-%02d-%02dT%02d:%02d:%02d" : "%04d%02d%02d%02d%02d%02d");
        my @t_ = localtime($t_);
        my $ret_;

        if (@t_) {
                $ret_ = sprintf($format_, $t_[5]+1900, $t_[4]+1, $t_[3], $t_[2], $t_[1], $t_[0]);
        }
        return $ret_;
}

sub getMD5 {
	my $s_ = shift;
	my $cmd_; 

	if (-f $s_) {
		$cmd_ = "md5sum '$s_'";
	}
	else {
		unless ($s_) {
			my $t_ = time;
			$s_ = "$HOST_NAME-$MD5_CNT-$$-$t_";
			$MD5_CNT++;
		}

		$cmd_ = "echo '$s_'|md5sum";
	}

	my @md5_ = split(/\s+/,scalar(qx($cmd_)));

	return $md5_[0];
}

sub getGUID {
	my $md5_ = getMD5(@_);
	return substr($md5_,0,8)
		. '-' . substr($md5_,0+8,4)
		. '-' . substr($md5_,0+8+4,4)
		. '-' . substr($md5_,0+8+4+4,4)
		. '-' . substr($md5_,0+8+4+4+4,12)
}

sub isUidGood {
	my $uid_ = shift;
	my $ret_;

	if ($uid_) {
		my @user_ = getpwnam($uid_);

		$ret_ = $uid_ if @user_;
	}
	return $ret_;
}

sub getBadUidsFromList {
	my @ret_;

	foreach (@_) {
        	my @user_ = getpwnam($_);

        	push @ret_, $_ unless @user_;
        }

	return @ret_;
}

sub getAbsPath {
	my $p_ = shift;
	my $ret_;

	if ($p_) {
		my $d_ = dirname($p_);
		if (-d $d_) {
			$ret_ = qx(cd $d_ && pwd); chomp $ret_;

			$ret_ = "$ret_/" . basename($p_);
		}
	}
	return $ret_;
}

sub getTmpDirName_ {
        return "$ENV{HOME}/tmp-" . getGUID();
}

sub getTmpDirName {
	my $ret_ = getTmpDirName_();

        push @TMP_DIR, $ret_;
        return $ret_;
}

sub getTmpDirList {
	return @TMP_DIR;
}

sub whackTmpDirList {
	foreach my $d_ (getTmpDirList()) {
		qx(/bin/rm -rf $d_) if -d $d_;
	}
}

sub getHostName() {
	return hostname();
}

sub hostname {
	return $HOST_NAME;
}

sub runNoHup {
	my %h_ = (@_, ExitCode => 2, ErrorMsg => "Usage : runNoHup(Email => uid, Cmd => '...')");
	my @req_ = qw(Email Cmd);
	my $cnt_;

	foreach (@req_) {
		$cnt_++ if $h_{$_};
	}

	if ($cnt_ eq scalar(@req_)) {
		$h_{TmpDir} = getTmpDirName_();
		$h_{ExitCode} = 0;
		delete $h_{ErrorMsg};

		silentRunCmd("mkdir -p $h_{TmpDir}");

		if (chdir($h_{TmpDir})) {
			my @nohup_ = qw(nohup.ksh nohup_out.txt nohup_err.txt);

			open(KSH, ">$nohup_[0]") or die "WOpen $nohup_[0] : $!";
			close KSH;

			if (chmod(0700, $nohup_[0]) && open(KSH, ">$nohup_[0]")) {
				print KSH "#!/usr/bin/ksh\n";
				print KSH "cd $h_{TmpDir}\n";
				print KSH "$h_{Cmd} 2>$nohup_[2] >$nohup_[1]\n";
				print KSH "EC=\$?\n";
				print KSH "cat $nohup_[1] | mailx -a $nohup_[2] -s '$HOST_NAME:$h_{Cmd}' $h_{Email}\n";
				print KSH "/bin/rm -rf $h_{TmpDir}\n";
				print KSH "exit \$EC\n";
				close KSH;

				$h_{ExitCode} = silentRunCmd("nohup $h_{TmpDir}/$nohup_[0] >/dev/null 2>&1 &");
			}
			else {
				$h_{ExitCode} = 2;
				$h_{ErrorMsg} = "chmod/wopen $nohup_[0] : $!";
			}
		}
		else {
			$h_{ExitCode} = 2;
			$h_{ErrorMsg} = "chdir $h_{TmpDir} : $!";
		}
	}

	return %h_;
}

sub old_runSql {
	my %h_ = @_;
	my @req_ = qw(KSH_TMP Connect ApplicationEnv ServerEnv Sql);
	my $cnt_;

	foreach (@req_) {
		$cnt_++ if $h_{$_};
	}

	if ($cnt_ eq scalar(@req_)) {
		open(KSH_TMP, ">$h_{KSH_TMP}") or die "Wopen $h_{KSH_TMP} : $!";
		print KSH_TMP "#!/usr/bin/ksh\n";
		close KSH_TMP;
		chmod 0700, $h_{KSH_TMP} or die "chmod $h_{KSH_TMP} : $!";
		open(KSH_TMP, ">>$h_{KSH_TMP}") or die "Wopen $h_{KSH_TMP} : $!";
		print KSH_TMP ". $h_{ServerEnv}\n";
		print KSH_TMP ". $h_{ApplicationEnv}\n";
		print KSH_TMP "\$ORACLE_HOME/bin/sqlplus -S /NOLOG << HERE\n";
		print KSH_TMP "$h_{Connect};\n";
		map { print KSH_TMP } @{$h_{Sql}};
		print KSH_TMP "quit;\n";
		print KSH_TMP "HERE\n";
		close(KSH_TMP);
		$h_{KSH_TMP_CONTENT} = qx(cat $h_{KSH_TMP});
		foreach (qx($h_{KSH_TMP} 2>&1)) {
			if (m!(ORA|SP2)-!) {
				chomp;
				push @{$h_{ORA}}, $_;
			}
			else {
				push @{$h_{OUT}}, $_;
			}
		}
	}
	return %h_;
}

sub runSql {
	my %h_ = @_;
	my @req_ = qw(KSH_TMP Connect Sql);
	my $cnt_;

	foreach (@req_) {
		$cnt_++ if $h_{$_};
	}

	if ($cnt_ eq scalar(@req_)) {
		open(KSH_TMP, ">$h_{KSH_TMP}") or die "Wopen $h_{KSH_TMP} : $!";
		print KSH_TMP "#!/usr/bin/ksh\n";
		close KSH_TMP;
		chmod 0700, $h_{KSH_TMP} or die "chmod $h_{KSH_TMP} : $!";
		open(KSH_TMP, ">>$h_{KSH_TMP}") or die "Wopen $h_{KSH_TMP} : $!";
		print KSH_TMP "$ENV{HOME}/etlsupp/bin/sqlplus -S /NOLOG << HERE\n";
		print KSH_TMP "$h_{Connect};\n";
		map { print KSH_TMP } @{$h_{Sql}};
		print KSH_TMP "quit;\n";
		print KSH_TMP "HERE\n";
		close(KSH_TMP);
		$h_{KSH_TMP_CONTENT} = qx(cat $h_{KSH_TMP});
		foreach (qx($h_{KSH_TMP} 2>&1)) {
			if (m!(ORA|SP2)-!) {
				chomp;
				push @{$h_{ORA}}, $_;
			}
			else {
				push @{$h_{OUT}}, $_;
			}
		}
	}
	return %h_;
}

sub getMDMList {
	my @ret_;

	foreach my $mdm_ (qx($BIN/jboss.pl -list)) {
		chomp $mdm_;

		push @ret_, $mdm_ if -d "$ENV{HOME}/$mdm_/infamdm/hub";
	}

	return @ret_;
}

sub getMDMHash {
	my %ret_;
	my @mdm_ = getMDMList();

	if (@_) {
		my %mdm_ = map { ($_, 1) } @mdm_;
		my %h_;

		foreach my $mdm_ (@_) {
			$h_{$mdm_}++ if $mdm_{$mdm_};
		}

		@mdm_ = keys %h_;
	}


	foreach my $mdm_ (@mdm_) {
		my %mdm_;
		my @glob_ = glob("/export/appl/website/jboss/$mdm_/*/bin/ServerEnv");

		$mdm_{domain} = $mdm_;

		if (-f $glob_[0]) {
			$mdm_{ServerEnv} = $glob_[0];
		}
		else {
			next;
		}

		@glob_ = glob("/export/appl/website/jbapp/$mdm_/conf/ApplicationEnv");
		if (-f $glob_[0]) {
			$mdm_{ApplicationEnv} = $glob_[0];
		}
		else {
			next;
		}

		@glob_ = glob("$ENV{HOME}/$mdm_/standalone-full-ha.xml");
		if (-f $glob_[0]) {
			$mdm_{config} = $glob_[0];

			foreach (getElements(scalar(qx(cat $mdm_{config})), 'xa-datasource')) {
				my %ds_;

				if(m!pool-name\s*=\s*\"([^\"]+)\"!) {
					$ds_{pool} = $1;
					foreach my $e_ (getElements($_, "xa-datasource-property")) {
						if ($e_ =~ m!name=\"URL\"!) {
							my $p_ = '//([^:]+):\d+/(\S+)';

							$ds_{url} = trimElementTag($e_);
							if ($ds_{url} =~ m!$p_!) {
								$ds_{dbhost} = $1;
								$ds_{sid} = $2;
							}
						}
					}

					foreach my $e_ (getElements($_, "security")) {
						map { $ds_{user} = trimElementTag($_) } getElements($e_, "user-name");
						map { $ds_{pass} = trimElementTag($_) } getElements($e_, "password");
					}

					if ($ds_{pass} =~ m!$EPV_PAT!) {
						$ENV{APP_CD} = $1;
						$ENV{ENV_CD} = $2;
						$ds_{epvRefID} = $3;

						foreach (qx($EPV_SCRIPT $ds_{epvRefID} 2>&1)) {
							if (m!$ds_{epvRefID}\.GetPassword=(\S+)!) {
								$ds_{pass} = $1;
								$ds_{Connect} = "connect $ds_{user}/$ds_{pass}\@$ds_{sid}";
								$ds_{epvOK}++;
							}
						}
					}
					else {
						$ds_{Connect} = "connect $ds_{user}/$ds_{pass}\@$ds_{sid}";
					}

					$ds_{schema} = uc("$ds_{user}\@$ds_{sid}");
					$mdm_{dataSources}{$ds_{schema}} = \%ds_;
				}
			}
					
		}
		else {
			next;
		}

		@glob_ = glob("/export/appl/website/jboss/$mdm_/*/bin/jboss-instance-ctl.sh");
		if (-f $glob_[0]) {
			foreach (qx($glob_[0] info)) {
				if (m!^HTTP_PORT=(\d+)!) {
					$mdm_{port} = $1;
				}
				if (m!^NODE_NAME=(\S+)!) {
					$mdm_{node} = $1;
				}
			}

			$mdm_{applicationSrv} = "http://$HOST_NAME:$mdm_{port}/cmx";
		}
		else {
			next;
		}

		@glob_ = glob("$ENV{HOME}/$mdm_/infamdm/hub/server/conf/versionInfo.xml");
		if (-f $glob_[0]) {
			my @grep_ = grep(/9\.5\.1/, qx(cat $glob_[0]));

			if(@grep_ > 0) {
				$mdm_{isa951}++;
			}
			else {
				@glob_ = glob("$ENV{HOME}/$mdm_/infamdm/hub/server/resources/cmxserver.properties");
				if (-f $glob_[0]) {
					@grep_ = grep(/^cmx.jboss7.security.enabled=true/,
						qx(cat $glob_[0]));

					foreach my $grep_ (@grep_) {
						$mdm_{cmx_jboss7_security_enabled}++;
					}
				}
			}
		}
		else {
			next;
		}

		$ret_{$mdm_{domain}} = \%mdm_;
	}

	return %ret_;
}

sub cmpFile {
	my $f1_ = shift;
	my $f2_ = shift;
	my $ret_;

	if (-f $f1_ && -f $f2_) {
		qx(cmp -s $f1_ $f2_);
		my $ec_ = $? >> 8;
		$ret_++ if $ec_ eq 0;
	}
	return $ret_;
}

sub readProps {
	my $p_ = shift;
	my %props_;

	if (-f $p_) {
		my $VAR1 = qx(cd $ENV{HOME} && $ENV{HOME}/etlsupp/java/bin/java -cp $ENV{HOME}/etlsupp/classes com.fanniemae.PropertyConvert $p_ toperl);

		if ($VAR1) {
			eval $VAR1;
			%props_ = %$VAR1;
		}
	}
	return %props_;
}

sub o_readProps {
	my $p_ = shift;
	my %props_;
	if ($p_ && open(PROPS, $p_)) {
		while (<PROPS>) {
			my $ls_ = '^\s*';
			my $ts_ = '\s*$';
			my $comment_ = '\#.*';
			my $prop_ = '^(\S+)\s*=\s*(.*)';
			s!$ts_!!;
			s!$comment_!!;
			s!$ls_!!;
			if (m!$prop_!) {
				$props_{$1} = $2
			}
		}
		close PROPS;
	}
	return %props_;
}

sub getElements {
	my $expr_ = shift;
	my $elem_ = shift;
	my @ret_ = ();

	if ($expr_ && $elem_) {
		my $i_ = 0;
		while (($i_ = index($expr_, "<$elem_", $i_)) > -1) {
			my $s_ = "</$elem_>";
			my $j_ = index($expr_, $s_, $i_);
			if ($j_ > -1) {
				$s_ = substr($expr_, $i_, $j_ - $i_ + length($s_));
				push @ret_, $s_;
				$i_ = $j_;
			}
			else {
				last;
			}
		}
	}
	return @ret_;
}

sub trimElementTag {
	my $s_ = shift || "";
	if ($s_) {
		foreach my $p_ (qw(^<[^>]+> </[^>]+>$)) {
			$s_ =~ s!$p_!!;
		}
		$s_ = trim($s_);
	}
	return $s_;
}

sub trim {
	my $s_ = shift;

	if (length($s_)) {
		foreach my $p_ (qw(^\s* \s*$)) {
			$s_ =~ s!$p_!!;
		}
	}
	else {
		$s_ = '';
	}

	return $s_;
}

sub silentRunCmd {
	qx(@_);
	return $? >> 8;
}

sub runCmd {
	my $cmd_ = "@_ 2>&1";

	print "$cmd_\n";
	print qx($cmd_);
	return $? >> 8;
}

sub runWithExitCheck {
	my $exit_ = runCmd(@_);
	myExit($exit_, "#####\n#####\n##### Failed($exit_) @_\n#####\n#####\n") if $exit_;
	return 0;
}

sub myExit {
	print "$_[1]\n" if $_[1];
	print "$0 EXIT_CODE=$_[0]\n";
	exit $_[0];
}

sub cdWithExitCheck {
	my $d_ = shift;
	my $pwd_;

	print "chdir $d_\n";
	if (chdir($d_)) {
		$pwd_ = qx(pwd); chomp $pwd_;
	}
	else {
		myExit(1, "#####\n#####\n##### Failed chdir $d_\n#####\n#####\n");
	}

	return $pwd_;
}

sub renameWithExitCheck {
	my $src_ = shift;
	my $dst_ = shift;

	print "rename($src_, $dst_)\n";
	unless (rename($src_, $dst_)) {
		print "#####\n#####\n##### Failed rename $src_ to $dst_\n#####\n#####\n";
		myExit(1);
	}
}

1;
