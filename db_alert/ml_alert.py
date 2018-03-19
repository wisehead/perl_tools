#!/usr/bin/python
"""
use the python code to fetch the SQLs from suspect_sql_new, then analyze it
with machine learning algorithm. then insert the injection SQL into ml_xxx_new.
Then the alert perl script will read it out and send it to security department.
"""
# -*- coding: UTF-8 -*-

import MySQLdb
from socket import *
#import socket
import time
import commands

CODE_VERSION = "1.0.0.5"

# fix-me: machine learning server is hard coded here, not good.
HOST = '127.0.0.1'
PORT = 21566
BUFSIZ = 1024
ADDR = (HOST, PORT)

always_true = 1

while (always_true == 1):
    # open the database connection. 
    # fix-me: database config is hard coded here, which is not good.
    db = MySQLdb.connect(host="127.0.0.1", port=6008, user="xxx", 
        passwd="1234", db="dbname")

    # use cursor() method to get the cursor.
    cursor = db.cursor()

    commands.getstatusoutput('touch the_last_scan_id.txt')
    file_object = open('the_last_scan_id.txt')
    try:
        the_last_scan_id_str = file_object.read()
    except:
        print "the the_last_scan_id.txt is empty."
    finally:
        file_object.close()

    if the_last_scan_id_str == "": 
        print "the_last_scan_id is empty."
        sql = " select auto_increment from information_schema.tables where table_name = \
        'suspect_sql_new' and table_schema = 'dbname'"
        cursor.execute(sql)
        results = cursor.fetchall()
        for row in results:
            the_last_scan_id = row[0] 
            print "the_last_scan_id is: %d" % the_last_scan_id
    else:
        print "the_last_scan_id is: %s" % the_last_scan_id_str
        the_last_scan_id = int(the_last_scan_id_str)

    # SQL Query 
    sql = "select * from suspect_sql_new where id>%d " % the_last_scan_id 
    try:
        # execute the SQL 
        cursor.execute(sql)
        # fetch all the records 
        results = cursor.fetchall()
        for row in results:
            id = row[0] 
            md5 = row[1] 
            logstash_id = row[2] 
            alarm_type = row[3]
            intrude_time = row[4]
            dbhost = row[5]
            port = row[6]
            user = row[7]        
            srchost = row[8]
            dbname = row[9]
            tblname = row[10]
            querycount = row[11]
            createtime = row[12]
            logtype = row[13]
            sql_text = row[14]
            dba = row[15]
            rd = row[16]         
            status = row[17]       
            appname = row[18]
            op = row[19]
            cor_id = row[20]  

            # print the output 
            print "intrude_time=%s,sql_text=%s" % \
                   (intrude_time, sql_text)
            if id > the_last_scan_id:
                the_last_scan_id = id
            try:
                tcpCliSock = socket(AF_INET, SOCK_STREAM)
                tcpCliSock.connect(ADDR)
                tcpCliSock.send(sql_text)
                data = tcpCliSock.recv(BUFSIZ)
                if not data:
                    print "Error: socket get no response data"
                    break
                print data
                if data == "1":
                    print "injection"
                    cursor_insert = db.cursor()
                    sql_insert = "INSERT INTO ml_xxx_new(md5,logstash_id,alarm_type, \
                    intrude_time,dbhost,port,user,srchost,dbname,tblname,querycount,createtime, \
                    logtype, sql_text,dba,rd,status,appname,op,cor_id) VALUES('%ld', '%s', '%s', \
                    '%s', '%d', '%d', '%s', '%s', '%s', '%s', '%d', '%s', '%s', '%s', '%s', '%s',\
                    '%d', '%s', '%s', '%ld')" % \
                    (md5, logstash_id, 'machine learning', intrude_time, dbhost, port, user, \
                    srchost, dbname, tblname, querycount, createtime, logtype, sql_text, dba, \
                    rd, status, appname, op, cor_id)
                    print "SQL_INSERT is: %s" % sql_insert
                    try:
                        cursor_insert.execute('INSERT INTO ml_xxx_new(md5,alarm_type, \
                        intrude_time,dbhost,port,user,srchost,dbname,tblname,querycount, \
                        createtime,logtype, sql_text,dba,rd,status,appname,op,cor_id) \
                        values("%ld", "%s", "%s", "%d", "%d", "%s", "%s", "%s", "%s", "%d", \
                        "%s", "%s", "%s", "%s", "%s", "%d", "%s", "%s", "%ld")' % \
                        (md5, 'machine learning', intrude_time, dbhost, port, user, srchost, \
                        dbname, tblname, querycount, createtime, logtype, sql_text, dba, rd, \
                        status, appname, op, cor_id))
                        # we need to commit the DML. otherwise it might be lost.
                        db.commit()
                    except Exception as e:
                        print 'str(Exception):%s\t', str(Exception)
                        print 'str(e):\t\t', str(e)
                        print 'repr(e):\t', repr(e)
                        print 'e.message:%s\t', e.message
                        print "Error: insert error"
                        #roll back if there are any errors. 
                        db.rollback()
                else:
                    print "normal"
                tcpCliSock.close()
            except:
                print "Error: Socket error"
    except:
        print "Error: unable to fecth data"


    print "the_last_scan_id is: %d" % the_last_scan_id
    the_last_scan_id_str = str(the_last_scan_id)

    file_object = open('the_last_scan_id.txt', 'w')
    try:
        the_last_scan_id_str = file_object.write(the_last_scan_id_str)
    except:
        print "write the_last_scan_id.txt failed."
    finally:
        file_object.close()

#close the database connection. 
    db.close()
    time.sleep(10)
