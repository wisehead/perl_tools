#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use Cwd;

my $config;
my $cwd = cwd();

my $interval = 0;
my $mailto = "";
my $client_cnf_file = "";
my $client = "";
my $db = "";
my @alarm_type_filter;
my @sql_text_filter;

my $start_check_time = time() - 12*60*60;
my $last_report_id = "";
my $last_report_id_ml = "";

open CONF, "alert.conf" or die "conf file does not exist!\n";

while (<CONF>)
{
    if (/^#/)
    {
        next;
    }

    if (/interval=(.+)/)
    {
        $interval = $1;
    }
    elsif (/mailto=(.+)/)
    {
        $mailto = $1;
    }
    elsif (/client_cnf_file=(.+)/)
    {
        $client_cnf_file = $1;
    }
    elsif (/client=(.+)/)
    {
        $client = $1;
    }
    elsif (/db=(.+)/)
    {
        $db = $1;
    }
    else
    {
        print "unrecognized config parameter.\n";
    }
}

close CONF;

print "interval: $interval, mailto: $mailto, client: $client, client_cnf_file: $client_cnf_file, db: $db\n";

if ($interval <= 0)
{
    die "error config, interval [$interval] should be greater than 0.\n";
}

if (! (-e $client))
{
    die "error config, client [$client] does not exist.\n";
}

if (! (-e $client_cnf_file))
{
    die "error config, client_cnf_file [$client_cnf_file] does not exist.\n";
}


if (-e "last_report_id.txt")
{
    my $lines = `cat last_report_id.txt`;
    ($last_report_id, $last_report_id_ml) = split /\n/, $lines;
}

while (1)
{
    my $timestamp = &get_timestamp();

    # This is the first time in the loop, set up the last_report_id and last_report_id_ml
    if ($last_report_id eq "")
    {
        &execute_sql("select auto_increment from information_schema.tables where table_name = 'ids_event' and table_schema = '$db' into outfile '$cwd/auto_increment.tmp'");
        $last_report_id = `cat $cwd/auto_increment.tmp`;
        $last_report_id -= 1000;
        unlink("$cwd/auto_increment.tmp");
    }

    if ($last_report_id_ml eq "")
    {
        &execute_sql("select auto_increment from information_schema.tables where table_name = 'ml_ids_event_new' and table_schema = '$db' into outfile '$cwd/auto_increment.tmp'");
        $last_report_id_ml = `cat $cwd/auto_increment_ml.tmp`;
        $last_report_id_ml -= 1000;
        unlink("$cwd/auto_increment_ml.tmp");
    }

    print "last report id: $last_report_id\n";
    print "last report id (ML): $last_report_id_ml\n";
    &execute_sql("select id, logstash_id, alarm_type, intrude_time, dbhost, port, user, srchost, dbname, tblname, ".
                        "querycount, createtime, logtype, dba, rd, status, appname, op, cor_id, replace(sql_text, '\n', ' ') ".
                 "from $db.ids_event ".
                 "where id > $last_report_id order by id into outfile '$cwd/$timestamp.ids_event.txt' FIELDS TERMINATED BY '|'");

    &execute_sql("select id, md5, logstash_id, alarm_type, intrude_time, dbhost, port, user, srchost, dbname, tblname, ".
                        "querycount, createtime, logtype, dba, rd, status, appname, op, cor_id, replace(sql_text, '\n', ' ') ".
                "from $db.ml_ids_event_new ".
                "where id > '$last_report_id_ml' order by id into outfile '$cwd/$timestamp.ml_ids_event.txt' FIELDS TERMINATED BY '|'");

    &send_mail("$timestamp.ids_event.txt", "$timestamp.ml_ids_event.txt");
    unlink ("$cwd/$timestamp.ids_event.txt");
    unlink ("$cwd/$timestamp.ml_ids_event.txt");

    system("echo $last_report_id > last_report_id.txt");
    system("echo $last_report_id_ml >> last_report_id.txt");
    sleep $interval;
}

sub execute_sql()
{
    my $sql = shift;
    my $cmd = "$client --defaults-file=$client_cnf_file $db".
              ' -e "'. $sql. '"';

    print "cmd: $cmd\n";
    system("$cmd");
}

sub get_timestamp()
{
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time());

    return sprintf("%d%02d%02d%02d%02d%02d",
                   ($year+1900), ($mon+1), ($mday),
                   $hour, $min, $sec);
}

sub send_mail()
{
    my $sql_file = shift;
    my $ml_ids_event_file = shift;
    my $host_name = `hostname`;
    chop ($host_name);

    &setup_filters();

    my $line = "";
    my ($id, $logstash_id, $alarm_type, $intrude_time, $dbhost, $port, $user, $srchost,
        $dbname, $tblname, $querycount, $createtime, $logtype, $dba, $rd, $status, $appname,
        $op, $cor_id, @sql_text);
    open FILE, "<$sql_file" or (warn "failed to open file $sql_file: $!\n" && return);
    while (<FILE>)
    {
        s/\\N//g;
        ($id, $logstash_id, $alarm_type, $intrude_time, $dbhost, $port, $user, $srchost,
         $dbname, $tblname, $querycount, $createtime, $logtype, $dba, $rd, $status, $appname,
         $op, $cor_id, @sql_text) = split /\|/;

        # Remove the trailing escape for the delimiter
        foreach (@sql_text)
        {
            s/\\//g;
            #chenhui
            #s/>/&#62;/g;
            #s/</&#60;/g;
            #s/=/&#61;/g;
        }

        my $sql_text = join ('|', @sql_text);

        if (&filter_line(\@alarm_type_filter, $alarm_type) ||
            &filter_line(\@sql_text_filter, $sql_text))
        {
            next;
        }
	system("perl $cwd/publish_alert $id");

        $line .= <<EOF;
  <tr>
    <td>$id</td>
    <td>$logstash_id</td>
    <td>$alarm_type</td>
    <td>$intrude_time</td>
    <td>$dbhost</td>
    <td>$port</td>
    <td>$user</td>
    <td>$srchost</td>
    <td>$dbname</td>
    <td>$tblname</td>
    <td>$querycount</td>
    <td>$createtime</td>
    <td>$logtype</td>
    <td>$dba</td>
    <td>$rd</td>
    <td>$status</td>
    <td>$appname</td>
    <td>$op</td>
    <td>$cor_id</td>
    <td>$sql_text</td>
  </tr>
EOF
    }

    close FILE;

    if ((defined $id) && ($id ne ""))
    {
        $last_report_id = $id;
    }

    if ($line eq "")
    {
        print "No SQL found in file $sql_file\n";
    }
    else
    {
        $line = <<EOF;
<h2><font face='Arial' size=5>Injected SQL</font></h2>
<table>
  <tr bgcolor='pink'>
    <th>ID</th>
    <th>Log Stash ID</th>
    <th>Alarm Type</th>
    <th>Intrusion time</th>
    <th>DB Host</th>
    <th>Port</th>
    <th>User</th>
    <th>Source Host</th>
    <th>DB Name</th>
    <th>Table Name</th>
    <th>Query Count</th>
    <th>Create Time</th>
    <th>Log Type</th>
    <th>DBA</th>
    <th>RD</th>
    <th>Status</th>
    <th>App Name</th>
    <th>OP</th>
    <th>Cor ID</th>
    <th>SQL Text</th>
  </tr>
  $line
</table>
EOF
    }

    my $ml_ids_event_line = "";
    my $md5;
    $id = "";
    $intrude_time = "";
    @sql_text = ();
    open FILE, "<$ml_ids_event_file" or (warn "failed to open file $ml_ids_event_file: $!\n" && return);
    while (<FILE>)
    {
        s/\\N//g;
        ($id, $md5, $logstash_id, $alarm_type, $intrude_time, $dbhost, $port, $user, $srchost,
         $dbname, $tblname, $querycount, $createtime, $logtype, $dba, $rd, $status, $appname,
         $op, $cor_id, @sql_text) = split /\|/;

        # Remove the tailing escape for the delimiter
        foreach (@sql_text)
        {
            s/\\//;
            #chenhui
            #s/>/&#62;/g;
            #s/</&#60;/g;
            #s/=/&#61;/g;
        }

        my $sql_text = join ('|', @sql_text);

        if (&filter_line(\@sql_text_filter, $sql_text))
        {
            next;
        }

        $ml_ids_event_line .= <<EOF;
  <tr>
    <td>$id</td>
    <td>$md5</td>
    <td>$logstash_id</td>
    <td>$alarm_type</td>
    <td>$intrude_time</td>
    <td>$dbhost</td>
    <td>$port</td>
    <td>$user</td>
    <td>$srchost</td>
    <td>$dbname</td>
    <td>$tblname</td>
    <td>$querycount</td>
    <td>$createtime</td>
    <td>$logtype</td>
    <td>$dba</td>
    <td>$rd</td>
    <td>$status</td>
    <td>$appname</td>
    <td>$op</td>
    <td>$cor_id</td>
    <td>$sql_text</td>
  </tr>
EOF
    }

    close FILE;

    if ((defined $id) && ($id ne ""))
    {
        $last_report_id_ml = $id;
    }

    if ($ml_ids_event_line eq "")
    {
        print "No SQL found in file $ml_ids_event_file\n";
    }
    else
    {
        $ml_ids_event_line = <<EOF;
<h2><font face='Arial' size=5>Machine Learning found SQL</font></h2>
<table>
  <tr bgcolor='pink'>
    <th>ID</th>
    <th>MD5</th>
    <th>Log Stash ID</th>
    <th>Alarm Type</th>
    <th>Intrusion time</th>
    <th>DB Host</th>
    <th>Port</th>
    <th>User</th>
    <th>Source Host</th>
    <th>DB Name</th>
    <th>Table Name</th>
    <th>Query Count</th>
    <th>Create Time</th>
    <th>Log Type</th>
    <th>DBA</th>
    <th>RD</th>
    <th>Status</th>
    <th>App Name</th>
    <th>OP</th>
    <th>Cor ID</th>
    <th>SQL Text</th>
  </tr>
  $ml_ids_event_line
</table>
EOF
    }

    if ($line eq "" and $ml_ids_event_line eq "")
    {
        return;
    }

    open(SENT,"|/usr/sbin/sendmail $mailto");

    print SENT <<EOF;
Mime-Version: 1.0
Content-Type: text/html
Content-Transfer-Encoding: 8BIT
From: mysql\@$host_name
To: $mailto
Subject: [Alarm] SQL Injection detected

<html>
<head>
    <title>SQL Injection Report</title>
</head>
<body>
<h1><font face='Arial' size=5>SQL Injection Report</font></h1>
<style>
  table {
    border-collapse: collapse;
  }
  th, td {
    border: 1px solid orange;
    padding: 10px;
    text-align: middle;
  }
</style>

$line
$ml_ids_event_line

</body>
</html>

EOF

    close SENT;
}

sub setup_filters()
{
    my $alarm_type_filter_section;
    my $sql_text_filter_section;

    # Empty and repopulate the filters
    @alarm_type_filter = ();
    @sql_text_filter = ();

    open FILE, "filters.conf" or (warn "failed to open filter config file: $!\n" && return);
    while(<FILE>)
    {
        if (/^\s*$/)
        {
            next;
        }

        if (/alarm type filter/)
        {
            $alarm_type_filter_section = 1;
            $sql_text_filter_section = 0;
            next;
        }
        elsif (/sql text filter/)
        {
            $alarm_type_filter_section = 0;
            $sql_text_filter_section = 1;
            next;
        }

        chop $_;

        s/\(|\)/\\$&/g;

        if ($alarm_type_filter_section)
        {
            push @alarm_type_filter, $_;
        }
        elsif ($sql_text_filter_section)
        {
            push @sql_text_filter, $_;
        }
    }

    close FILE;

    print Dumper \@alarm_type_filter;
    print Dumper \@sql_text_filter;
}

sub filter_line()
{
    my $filters = shift;
    my $text = shift;

    foreach my $filter (@$filters)
    {
	#chenhui
	#print "text:".$text."\n";
	#print "filter:".$filter."\n";
        if ($text =~ /$filter/)
        {
            return 1;
        }
    }

    return 0;
}
