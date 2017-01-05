#!/usr/bin/python

def qx(cmd):
        import subprocess

        pipe_ = subprocess.Popen(cmd, stdout=subprocess.PIPE, shell=True, bufsize=-1, close_fds=True)
        try:
                for l_ in pipe_.stdout:
                        s_ = l_.rstrip()
                        if len(s_) > 0: yield(s_)
        finally:
                pipe_.stdout.close()

MAX_LEN = 0
OUT = dict();

for fs_ in ['/tmp', '/var/tmp']:
        bytes_ = [];
        h_ = dict();

        if len(fs_) > MAX_LEN:
                MAX_LEN = len(fs_)

        for qx_ in qx("find %s -type f -ls 2>/dev/null" % (fs_)):
                a_ = qx_.split()

                if a_[4] in h_:
                        h_[a_[4]] += int(a_[6])
                else:
                        h_[a_[4]] = 0

        for user_ in h_:
                k_ = h_[user_]/1024
                m_ = k_/1024
                g_ = m_/1024

                bytes_.append("%10.10dK %6.6dM %6.6dG %s" % (int(k_), int(m_), int(g_), user_))

        OUT[fs_] = sorted(bytes_)

PAGE_BREAK = 0

for fs_ in sorted(OUT):
        if PAGE_BREAK > 0:
                print('')

        for s_ in  OUT[fs_]:
                fmt_ = "%" + str(MAX_LEN) + "s %s"
                print(fmt_ % (fs_, s_))

        for s_ in qx('df -k ' + fs_):
                print(s_)

        PAGE_BREAK += 1
