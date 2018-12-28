#!/usr/bin/perl

#
# Get the log files containing SQL statements, and then pass them to
# dtest - the intrusion detection test program.
#

use strict;
use warnings;

use Data::Dumper;
use Cwd;

my $config;
my $cwd = cwd();

opendir DIR, "conf" or die "conf dir does not exist!\n";
while(my $conf = readdir(DIR))
{
    if ($conf !~ /(.+)\.conf$/)
    {
        next;
    }

    &process_set($1);
}

close DIR;

sub process_set()
{
    my $set_name = shift;
    my $timestamp = &get_timestamp();

    mkdir "$set_name.$timestamp" 
        or die "failed to create directory: $set_name.$timestamp: $!\n";

    # Redirect all the messages into the log files.
    open STDOUT, ">$set_name.$timestamp/runner.log" 
        or die "failed to open the log file for $set_name.$timestamp/runner.log: $!\n";

    print "current timestamp: $timestamp\n";
    print "set name: $set_name\n";

    &get_config("conf/$set_name.conf");

    if (not defined $config || scalar @{$config->{LOG_HOST}} == 0)
    {
        print "configure is not complete, skip this data set.\n";
        close STDOUT;

        return;
    }

    chdir "$set_name.$timestamp";

    foreach my $host (@{$config->{LOG_HOST}})
    {
        print "Process files on host $host.\n";

        $config->{FILE_LIST} = &get_file_list();

        print "Download the log files with wget...\n";
        foreach my $file (@{$config->{FILE_LIST}})
        {
            if (-e $file)
            {
                print "file $file already exists, remove before wget a new one\n";
                unlink($file);
            }

            print "cmd: [wget --limit-rate=10000000 ftp://$host:". $config->{LOG_PATH}. "/$file -nv 2>&1]\n";
            system("wget --limit-rate=10000000 ftp://$host:". $config->{LOG_PATH}. "/$file -nv 2>&1");
        }

        print "Prepare to invoke the dtest program\n";

        &invoke_dtest($host);
    }

    close STDOUT;

    chdir $cwd;

    return;
}

sub invoke_dtest()
{
    my $host      = shift;
    my $pwd  = cwd();

    # Set up the dtest config file
    &setup_dtest_config();

    print Dumper $config;

    # Truncate the tables for normal sql and ids_event
    print "Truncate the tables ids_event and normal_sql in case there are records in them.\n";
    &cleanup_database();

    # Execute dtest program
    print "Execute dtest to check the SQL statements in the log files\n";
    chdir "$cwd/sqlparser";
    system("export LD_LIBRARY_PATH=$cwd/sqlparser/mysql-connector/lib; ".
           "$cwd/sqlparser/dtest > $pwd/$host.dtest.log");

    chdir $pwd;

    &post_dtest($host);
}

sub post_dtest()
{
    my $host = shift;
    my $pwd  = cwd();

    # Generate Report
    print "Generate the test report....\n";
    &execute_sql("select count(sql_text) from ". $config->{DB}.".normal_sql");
    &execute_sql("select count(sql_text), alarm_type from ". $config->{DB}.".ids_event group by alarm_type");

    # Export sqls in the tables into files
    print "Export the SQL statements into files for future investigations.\n";
    &execute_sql("select distinct sql_text, alarm_type from ". $config->{DB}.".ids_event  into outfile '$pwd/$host.ids_event.txt'");
    &execute_sql("select sql_text, id from ". $config->{DB}.".normal_sql into outfile '$pwd/$host.normal_sql.txt'");

    # truncate the tables
    print "Truncate the ids_event and normal_sql tables\n";
    &cleanup_database();

    # backup the configure file which dtest is using, and restore the original one
    system("cp $cwd/sqlparser/conf/dtest.conf $pwd/$host.dtest.conf");
    system("cp $pwd/dtest.conf.backup $cwd/sqlparser/conf/dtest.conf");

    # delete the log files
    print "clean up the log file\n";
    for my $file (@{$config->{FILE_LIST}})
    {
        if (-e $file)
        {
            # unlink($file) or print "failed to remove file $file: $!\n";
        }
    }
}

sub cleanup_database()
{
    &execute_sql("truncate table ". $config->{DB}.".ids_event; ".
                 "truncate table ". $config->{DB}.".normal_sql");
}

sub execute_sql()
{
    my $sql = shift;
    my $cmd = "mysql -u ". $config->{DB_USER}.
              " --host ". $config->{DB_HOST}.
              " --port ". $config->{DB_PORT}.
              " --socket=". $config->{DB_SOCKET}.
              " --password=". $config->{DB_PASSWORD}.
              ' -e "'. $sql. '"';

    print "cmd: $cmd\n";
    system("$cmd");
}

sub setup_dtest_config()
{
    my $pwd = cwd();

    print "Set config for dtest.\n";

    # backup the dtest config file
    system("cp $cwd/sqlparser/conf/dtest.conf $pwd/dtest.conf.backup");

    open DTEST_CONF, ">$cwd/sqlparser/conf/dtest.conf"
        or die "failed to open new dtest config file [$cwd/sqlparser/conf/dtest.conf]: $!\n";
    open DTEST_BAK, "<$pwd/dtest.conf.backup"
        or die "failed to open dtest config backup file [dtest.conf.backup]: $!\n";

    print DTEST_CONF "sql_file_format=". $config->{LOG_TYPE}. "\n";

    while (my $line = <DTEST_BAK>)
    {
        if ($line =~ /(^#)|(sql_file)|(sql_file_format)/)
        {
            next;
        }

        if ($line =~ /host=(.+)/)
        {
            if (not defined $config->{DB_HOST})
            {
                $config->{DB_HOST} = $1;
            }

            print DTEST_CONF "host=".
                             $config->{DB_HOST}.
                             "\n";
        }
        elsif ($line =~ /port=(.+)/)
        {
            if (not defined $config->{DB_PORT})
            {
                $config->{DB_PORT} = $1;
            }

            print DTEST_CONF "port=".
                             $config->{DB_PORT}.
                             "\n";
        }
        elsif ($line =~ /db=(.+)/)
        {
            if (not defined $config->{DB})
            {
                $config->{DB} = $1;
            }

            print DTEST_CONF "db=".
                             $config->{DB}.
                             "\n";
        }
        elsif ($line =~ /user=(.+)/)
        {
            if (not defined $config->{DB_USER})
            {
                $config->{DB_USER} = $1;
            }

            print DTEST_CONF "user=".
                             $config->{DB_USER}.
                             "\n";
        }
        elsif ($line =~ /password=(.+)/)
        {
            if (not defined $config->{DB_PASSWORD})
            {
                $config->{DB_PASSWORD} = $1;
            }

            print DTEST_CONF "password=".
                             $config->{DB_PASSWORD}.
                             "\n";
        }
        elsif ($line =~ /socket=(.+)/)
        {
            if (not defined $config->{DB_SOCKET})
            {
                $config->{DB_SOCKET} = $1;
            }

            print DTEST_CONF "socket=".
                             $config->{DB_SOCKET}.
                             "\n";
        }
        elsif ($line =~ /sql_file_format/ && defined $config->{LOG_TYPE})
        {
            print DTEST_CONF "sql_file_format=".
                             $config->{LOG_TYPE}.
                             "\n";
        }
        else
        {
            print DTEST_CONF $line;
        }
    }

    foreach my $file (@{$config->{FILE_LIST}})
    {
        print DTEST_CONF "sql_file=$pwd/$file\n";
    }

    close DTEST_CONF;
    close DTEST_BAK;
}

sub get_config()
{
    my $conf_file = shift;
    my @host_list;

    undef $config;

    open CONF, "<$conf_file" or die "open config file $conf_file failed: $!\n";

    while (<CONF>)
    {
        if (/^#/)
        {
            next;
        }

        if (/host=(.+)/)
        {
            push @host_list, $1;
        }
        elsif(/path=(.+)/)
        {
            $config->{LOG_PATH} = $1
        }
        elsif(/log_type=(.+)/)
        {
            $config->{LOG_TYPE} = $1;
        }
        elsif(/dbhost=(.+)/)
        {
            $config->{DB_HOST} = $1;
        }
        elsif(/dbport=(.+)/)
        {
            $config->{DB_PORT} = $1;
        }
        elsif(/db=(.+)/)
        {
            $config->{DB} = $1;
        }
        elsif(/dbuser=(.+)/)
        {
            $config->{DB_USER} = $1;
        }
        elsif(/dbpassword=(.+)/)
        {
            $config->{DB_PASSWORD} = $1;
        }
        elsif(/dbsocket=(.+)/)
        {
            $config->{DB_SOCKET} = $1;
        }
    }

    close CONF;

    $config->{LOG_HOST} = \@host_list;
}

sub get_timestamp()
{
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time());

    return sprintf("%d%02d%02d%02d%02d%02d",
                   ($year+1900), ($mon+1), ($mday),
                   $hour, $min, $sec);
}

sub get_file_list()
{
    my $today     = &get_date();
    my $yesterday = &get_date_yesterday();
    my $hour      = &get_current_hour();
    my @filelist;

    for(my $i = $hour; $i < $hour + 24; $i++)
    {
        if ($i > 23)
        {
            push @filelist, &get_file_name(sprintf("$today%02d", $i-24));
        }
        else 
        {
            push @filelist, &get_file_name(sprintf("$yesterday%02d", $i));
        }
    }

    return \@filelist;
}

sub get_file_name()
{
    my $date = shift;
    my $file_name = "";

    if ($config->{LOG_TYPE} eq "proxy_log")
    {
        $file_name = "dbproxy.log.$date";
    }

    return $file_name;
}

sub get_date()
{
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time());

    return sprintf("%d%02d%02d",
                   ($year+1900), ($mon+1), $mday);
}

sub get_date_yesterday()
{
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time() - 60*60*24*3); # check the past 3 days

    return sprintf("%d%02d%02d",
                   ($year+1900), ($mon+1), $mday);
}

sub get_current_hour()
{
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time());

    return $hour;
}
