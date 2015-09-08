package TiedScalar;
require Tie::Scalar;

@ISA = (Tie::StdScalar);

my $EPV_PAT = '\$\{VAULT::(\w+)::(\w+)::(\w+)\}';

sub FETCH {
        my $self_ = shift;
        my $href_ = $$self_;
        my $ret_;

        unless ($href_->{ds}{_epvOK}) {
                if ($href_->{ds}{password} =~ m!$EPV_PAT!) {
                        my $refId_ = $3;

                        foreach my $qx_ (qx(APP_CD=$1 ENV_CD=$2 $ENV{HOME}/etlsupp/bin/EPVDisplay.ksh $refId_ 2>&1)) {
                                if ($qx_ =~ m!$refId_\.GetPassword=(\S+)!) {
                                        my $pass_ = $1;
                                        my $user_ = $href_->{ds}{user};
                                        my $sid_ = $href_->{ds}{sid};

                                        $href_->{ds}{_Connect} = "connect $user_/$pass_\@$sid_";
                                        $href_->{ds}{_pass} = $pass_;
                                        $href_->{ds}{_epvOK}++;
                                        last;
                                }
                        }
                }
        }

        if ($href_->{ds}{_epvOK}) {
                my $name_ = "_" . $href_->{name};

                $ret_ = $href_->{ds}{$name_};
        }

        return $ret_;
}

sub STORE {
        my $self_ = shift;
        my $val_ = shift;
        my $href_ = $$self_;
        my $name_ = "_" . $href_->{name};

        $href_->{ds}{$name_} = $val_;
}
