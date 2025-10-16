# Single-container Slurm and ssh container for ci/cd testing of Slurm interface
#
# Copyright (c) 2025  Manuel G. Marciani
# BSC-CNS - Earth Sciences

ARG SLURM_TAG=25-05-0-1

# ---------------------------------------------------------------------------------------------------------------------
# Build layer

FROM debian:stable-slim AS build

LABEL org.opencontainers.image.source="https://github.com/manuel-g-castro/slurm-cluster-openssh-docker/" \
      org.opencontainers.image.title="slurm-cluster-openssh-docker" \
      org.opencontainers.image.description="Slurm Docker cluster on Debian Slim with an OpenSSH server" 

ARG SLURM_TAG

# install openssh server 

RUN apt-get update && \
    apt-get --no-install-recommends -y install make \
        automake \
        autoconf \
        build-essential \
        bzip2 \
        ca-certificates \
        debianutils \
        dirmngr \
        g++ \
        gcc \
        git \
        gpg \
        gpg-agent \
        libcurl4 \
        libglib2.0-dev \
        libgtk2.0-dev \
        libmariadbd-dev \
        libpam0g-dev \
        libtool \
        libncurses-dev \
        libgdm1 \
        libmunge2 \
        libmunge-dev \
        libssl-dev \
        libdbus-1-dev \
        mariadb-client \
        mariadb-server \
        munge \
        wget \
        zlib1g \
        zlib1g-dev && \
    update-ca-certificates

RUN git clone -b ${SLURM_TAG} --single-branch --depth=1 https://github.com/SchedMD/slurm.git && \
    cd slurm && \
    ./configure \
        --enable-debug \
        --prefix=/usr \
        --sysconfdir=/etc/slurm \
        --with-mysql_config=/usr/bin \
        --libdir=/usr/lib64 && \
    make install && \
    install -D -m644 etc/cgroup.conf.example /etc/slurm/cgroup.conf.example && \
    install -D -m644 etc/slurm.conf.example /etc/slurm/slurm.conf.example && \
    install -D -m644 etc/slurmdbd.conf.example /etc/slurm/slurmdbd.conf.example && \
    install -D -m644 contribs/slurm_completion_help/slurm_completion.sh /etc/profile.d/slurm_completion.sh

# ---------------------------------------------------------------------------------------------------------------------
# Slurm runtime layer
# NOTE: Without multi-stage builds, the final image has about 1.86 GB, with it has 1.03 GB (~ -45%).

FROM debian:stable-slim

LABEL org.opencontainers.image.source="https://github.com/manuel-g-castro/slurm-cluster-openssh-docker/" \
      org.opencontainers.image.title="slurm-cluster-openssh-docker" \
      org.opencontainers.image.description="Slurm Docker cluster on Debian Slim with an OpenSSH server" 

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
# manuel: set the username for the run script
ENV USERNAME=root

# Install dependencies. NOTE: you must include the runtime dependencies
# for Slurm, AND the dependencies for Autosubmit, since this node will
# be used for running jobs (e.g. `python3` for wrappers, `graphviz` for
# plots...).

RUN apt-get update && \
    apt-get --no-install-recommends -y install \
        bash \
        ca-certificates \
        less \
        locales \
        mariadb-server \
        openssh-server \
        python3 \
        tini \
        vim \
        xz-utils && \
    update-ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# COPY from build layer
# NOTE: We exclude the following:
#       - /usr/share man files (users can consult it online or on the host machine)
# - binaries
COPY --from=build /usr/bin/sacct /usr/bin/sacct
COPY --from=build /usr/bin/sacctmgr /usr/bin/sacctmgr
COPY --from=build /usr/bin/sattach /usr/bin/sattach
COPY --from=build /usr/bin/salloc /usr/bin/salloc
COPY --from=build /usr/bin/sbatch /usr/bin/sbatch
COPY --from=build /usr/bin/scancel /usr/bin/scancel
COPY --from=build /usr/bin/sbcast /usr/bin/sbcast
COPY --from=build /usr/bin/scrontab /usr/bin/scrontab
COPY --from=build /usr/bin/scontrol /usr/bin/scontrol
COPY --from=build /usr/bin/sdiag /usr/bin/sdiag
COPY --from=build /usr/bin/sinfo /usr/bin/sinfo
COPY --from=build /usr/bin/sprio /usr/bin/sprio
COPY --from=build /usr/bin/squeue /usr/bin/squeue
COPY --from=build /usr/bin/sreport /usr/bin/sreport
COPY --from=build /usr/bin/sshare /usr/bin/sshare
COPY --from=build /usr/bin/srun /usr/bin/srun
COPY --from=build /usr/bin/sstat /usr/bin/sstat
COPY --from=build /usr/bin/strigger /usr/bin/strigger
COPY --from=build /usr/bin/sview /usr/bin/sview
# more binaries
COPY --from=build /usr/sbin/slurmctld /usr/sbin/slurmctld
COPY --from=build /usr/sbin/slurmd /usr/sbin/slurmd
COPY --from=build /usr/sbin/slurmstepd /usr/sbin/slurmstepd
COPY --from=build /usr/sbin/slurmdbd /usr/sbin/slurmdbd
# - include headers
COPY --from=build /usr/include/slurm /usr/include/slurm
# - libraries
COPY --from=build /usr/lib64/libslurm.so.43.0.0 /usr/lib64/libslurm.so.43.0.0
COPY --from=build /usr/lib64/libslurm.so.43 /usr/lib64/libslurm.so.43
COPY --from=build /usr/lib64/libslurm.so /usr/lib64/libslurm.so
COPY --from=build /usr/lib64/libslurm.la /usr/lib64/libslurm.la
COPY --from=build /usr/lib64/libslurm.a /usr/lib64/libslurm.a
COPY --from=build /usr/lib64/slurm /usr/lib64/slurm

RUN mkdir -p /etc/sysconfig/slurm \
        /var/spool/slurmd \
        /var/run/slurmd \
        /var/run/slurmdbd \
        /var/lib/slurmd \
        /var/log/slurm \
        /data && \
    touch /var/lib/slurmd/node_state \
        /var/lib/slurmd/front_end_state \
        /var/lib/slurmd/job_state \
        /var/lib/slurmd/resv_state \
        /var/lib/slurmd/trigger_state \
        /var/lib/slurmd/assoc_mgr_state \
        /var/lib/slurmd/assoc_usage \
        /var/lib/slurmd/qos_usage \
        /var/lib/slurmd/fed_mgr_state

RUN ssh-keygen -q -t rsa -N '' -f /root/.ssh/container_root_pubkey

# Set up login to SSH
RUN mkdir -p /root/.ssh/ && \
    cat /root/.ssh/container_root_pubkey.pub >> /root/.ssh/authorized_keys && \
    chmod -R 700 /root/.ssh/ && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config && \
    echo 'Port=2222' >> /etc/ssh/sshd_config && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config

# SSH set up
# Ref: https://askubuntu.com/questions/1110828/ssh-failed-to-start-missing-privilege-separation-directory-var-run-sshd
RUN mkdir -p /var/run/sshd && \
    chmod 0755 /var/run/sshd

# Create folder to simulate the projects used in Marenostrum and for the tests
RUN mkdir -p /tmp/scratch/group/root

# Set the locale.
# Ref: https://jaredmarkell.com/docker-and-locales/
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen

# Copy Slurm configuration files into the container
COPY slurm.conf /etc/slurm/slurm.conf
COPY slurmdbd.conf /etc/slurm/slurmdbd.conf
COPY cgroup.conf /etc/slurm/cgroup.conf
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod 600 /etc/slurm/slurm.conf /etc/slurm/slurmdbd.conf

EXPOSE 2222

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/docker-entrypoint.sh"]
