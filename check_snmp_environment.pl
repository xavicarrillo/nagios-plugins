#!/usr/bin/perl -w 
############################## check_snmp_environment #########
# Version : 0.5
# Date: August 20 2008
# Author  : Michiel Timmers ( michiel.timmers AT gmx.net)
# Based on the following plugin with the aditional ciscoSW and juniper options
############################## check_snmp_env #################
# Version : 1.3
# Date : Jun 20 2007
# Author  : Patrick Proy ( patrick at proy.org)
# Help : http://www.manubulon.com/nagios/
# Licence : GPL - http://www.fsf.org/licenses/gpl.txt
# Changelog : 
# Contributors : Fredrik Vocks
#################################################################
#
# Help : ./check_snmp_env.pl -h
#

use strict;
use Net::SNMP;
use Getopt::Long;

# Nagios specific

#use lib "/usr/local/nagios/libexec";
#use utils qw(%ERRORS $TIMEOUT);
my $TIMEOUT = 15;
my %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);


my @Nagios_state = ("UNKNOWN","OK","WARNING","CRITICAL"); # Nagios states coding

# SNMP Datas

# CISCO-ENVMON-MIB
my $ciscoEnvMonMIB	=	"1.3.6.1.4.1.9.9.13"; # Cisco env base table
my %CiscoEnvMonState = (1,"normal",2,"warning",3,"critical",4,"shutdown",5,"notPresent",
						6,"notFunctioning"); # Cisco states
my %CiscoEnvMonNagios = (1,1 ,2,2 ,3,3 ,4,3 ,5,0, 6,3); # Nagios states returned for CIsco states (coded see @Nagios_state).
my $ciscoVoltageTable = $ciscoEnvMonMIB.".1.2.1"; # Cisco voltage table
my $ciscoVoltageTableIndex = $ciscoVoltageTable.".1"; #Index table
my $ciscoVoltageTableDesc = $ciscoVoltageTable.".2"; #Description
my $ciscoVoltageTableValue = $ciscoVoltageTable.".3"; #Value
my $ciscoVoltageTableState = $ciscoVoltageTable.".7"; #Status
# CiscoEnvMonVoltageStatusEntry ::=
                # 1 ciscoEnvMonVoltageStatusIndex   Integer32 (0..2147483647),
                # 2 ciscoEnvMonVoltageStatusDescr   DisplayString,
                # 3 ciscoEnvMonVoltageStatusValue   CiscoSignedGauge,
                # 4 ciscoEnvMonVoltageThresholdLow  Integer32,
                # 5 ciscoEnvMonVoltageThresholdHigh Integer32,
                # 6 ciscoEnvMonVoltageLastShutdown  Integer32,
                # 7 ciscoEnvMonVoltageState         CiscoEnvMonState
my $ciscoTempTable = $ciscoEnvMonMIB.".1.3.1"; # Cisco temprature table
my $ciscoTempTableIndex = $ciscoTempTable.".1"; #Index table
my $ciscoTempTableDesc = $ciscoTempTable.".2"; #Description
my $ciscoTempTableValue = $ciscoTempTable.".3"; #Value
my $ciscoTempTableState = $ciscoTempTable.".6"; #Status
# CiscoEnvMonTemperatureStatusEntry ::=
                # ciscoEnvMonTemperatureStatusIndex       Integer32 (0..2147483647),
                # ciscoEnvMonTemperatureStatusDescr       DisplayString,
                # ciscoEnvMonTemperatureStatusValue       Gauge32,
                # ciscoEnvMonTemperatureThreshold         Integer32,
                # ciscoEnvMonTemperatureLastShutdown      Integer32,
                # ciscoEnvMonTemperatureState             CiscoEnvMonState
my $ciscoFanTable = $ciscoEnvMonMIB.".1.4.1"; # Cisco fan table
my $ciscoFanTableIndex = $ciscoFanTable.".1"; #Index table
my $ciscoFanTableDesc = $ciscoFanTable.".2"; #Description
my $ciscoFanTableState = $ciscoFanTable.".3"; #Status
# CiscoEnvMonFanStatusEntry ::=
                # ciscoEnvMonFanStatusIndex       Integer32 (0..2147483647),
                # ciscoEnvMonFanStatusDescr       DisplayString,
                # ciscoEnvMonFanState             CiscoEnvMonState
my $ciscoPSTable = $ciscoEnvMonMIB.".1.5.1"; # Cisco power supply table
my $ciscoPSTableIndex = $ciscoPSTable.".1"; #Index table
my $ciscoPSTableDesc = $ciscoPSTable.".2"; #Description
my $ciscoPSTableState = $ciscoPSTable.".3"; #Status
# CiscoEnvMonSupplyStatusEntry ::=
                # ciscoEnvMonSupplyStatusIndex    Integer32 (0..2147483647),
                # ciscoEnvMonSupplyStatusDescr    DisplayString,
                # ciscoEnvMonSupplyState          CiscoEnvMonState,
                # ciscoEnvMonSupplySource         INTEGER

# Nokia env mib 
my $nokia_temp_tbl=	"1.3.6.1.4.1.94.1.21.1.1.5";
my $nokia_temp=		"1.3.6.1.4.1.94.1.21.1.1.5.0";
my $nokia_fan_table=	"1.3.6.1.4.1.94.1.21.1.2";
my $nokia_fan_status=	"1.3.6.1.4.1.94.1.21.1.2.1.1.2";
my $nokia_ps_table=	"1.3.6.1.4.1.94.1.21.1.3";
my $nokia_ps_temp=	"1.3.6.1.4.1.94.1.21.1.3.1.1.2";
my $nokia_ps_status=	"1.3.6.1.4.1.94.1.21.1.3.1.1.3";

# Bluecoat env mib
my @bc_SensorCode=("","ok","unknown","not-installed","voltage-low-warning","voltage-low-critical",
	"no-power","voltage-high-warning","voltage-high-critical","voltage-high-severe",
	"temperature-high-warning","temperature-high-critical","temperature-high-severe",
	"fan-slow-warning","fan-slow-critical","fan-stopped"); # BC element status returned by MIB
my @bc_status_nagios=(3,0,3,3,1,2,2,1,2,2,1,2,2,1,2,2); # nagios status equivallent to BC status
my @bc_SensorStatus=("","ok","unavailable","nonoperational"); # ok(1),unavailable(2),nonoperational(3)
my @bc_mesure=("","","","Enum","volts","celsius","rpm");

my @bc_DiskStatus=("","present","initializing","inserted","offline","removed","not-present","empty","bad","unknown");
my @bc_dsk_status_nagios=(3,0,0,1,1,1,2,2,2,3);

my $bc_sensor_table		= "1.3.6.1.4.1.3417.2.1.1.1.1.1"; # sensor table
my $bc_sensor_units 	= "1.3.6.1.4.1.3417.2.1.1.1.1.1.3"; # cf bc_mesure
my $bc_sensor_Scale 	= "1.3.6.1.4.1.3417.2.1.1.1.1.1.4"; # * 10^value
my $bc_sensor_Value 	= "1.3.6.1.4.1.3417.2.1.1.1.1.1.5"; # value
my $bc_sensor_Code 		= "1.3.6.1.4.1.3417.2.1.1.1.1.1.6"; # bc_SensorCode
my $bc_sensor_Status 	= "1.3.6.1.4.1.3417.2.1.1.1.1.1.7"; # bc_SensorStatus
my $bc_sensor_Name 		= "1.3.6.1.4.1.3417.2.1.1.1.1.1.9"; # name

my $bc_dsk_table 	= "1.3.6.1.4.1.3417.2.2.1.1.1.1"; #disk table
my $bc_dsk_status 	= "1.3.6.1.4.1.3417.2.2.1.1.1.1.3"; # cf 	bc_DiskStatus
my $bc_dsk_vendor 	= "1.3.6.1.4.1.3417.2.2.1.1.1.1.5"; # cf 	bc_DiskStatus
my $bc_dsk_serial 	= "1.3.6.1.4.1.3417.2.2.1.1.1.1.8"; # cf 	bc_DiskStatus
		
# Ironport env mib

my $iron_ps_table 	= "1.3.6.1.4.1.15497.1.1.1.8"; # ps table
my $iron_ps_status 	= "1.3.6.1.4.1.15497.1.1.1.8.1.2"; # ps status 
#powerSupplyNotInstalled(1), powerSupplyHealthy(2), powerSupplyNoAC(3), powerSupplyFaulty(4)
my @iron_ps_status_name=("","powerSupplyNotInstalled","powerSupplyHealthy","powerSupplyNoAC","powerSupplyFaulty");
my @iron_ps_status_nagios=(3,3,0,2,2);
my $iron_ps_ha 		= "1.3.6.1.4.1.15497.1.1.1.8.1.3"; # ps redundancy status
#powerSupplyRedundancyOK(1), powerSupplyRedundancyLost(2)
my @iron_ps_ha_name=("","powerSupplyRedundancyOK","powerSupplyRedundancyLost");
my @iron_ps_ha_nagios=(3,0,1);
my $iron_ps_name 	= "1.3.6.1.4.1.15497.1.1.1.8.1.4"; # ps name

my $iron_tmp_table	= "1.3.6.1.4.1.15497.1.1.1.9"; # temp table
my $iron_tmp_celcius	= "1.3.6.1.4.1.15497.1.1.1.9.1.2"; # temp in celcius
my $iron_tmp_name	= "1.3.6.1.4.1.15497.1.1.1.9.1.3"; # name

my $iron_fan_table	= "1.3.6.1.4.1.15497.1.1.1.10"; # fan table
my $iron_fan_rpm	= "1.3.6.1.4.1.15497.1.1.1.10.1.2"; # fan speed in RPM
my $iron_fan_name	= "1.3.6.1.4.1.15497.1.1.1.10.1.3"; # fan name

# Foundry BigIron Router Switch (FOUNDRY-SN-AGENT-MIB)

my $foundry_temp 	= "1.3.6.1.4.1.1991.1.1.1.1.18.0"; # Chassis temperature in Deg C *2
my $foundry_temp_warn 	= "1.3.6.1.4.1.1991.1.1.1.1.19.0"; # Chassis warn temperature in Deg C *2
my $foundry_temp_crit 	= "1.3.6.1.4.1.1991.1.1.1.1.20.0"; # Chassis warn temperature in Deg C *2
my $foundry_ps_table	= "1.3.6.1.4.1.1991.1.1.1.2.1"; # PS table
my $foundry_ps_desc	= "1.3.6.1.4.1.1991.1.1.1.2.1.1.2"; # PS desc
my $foundry_ps_status	= "1.3.6.1.4.1.1991.1.1.1.2.1.1.3"; # PS status
my $foundry_fan_table	= "1.3.6.1.4.1.1991.1.1.1.3.1"; # FAN table
my $foundry_fan_desc	= "1.3.6.1.4.1.1991.1.1.1.3.1.1.2"; # FAN desc
my $foundry_fan_status	= "1.3.6.1.4.1.1991.1.1.1.3.1.1.3"; # FAN status

my @foundry_status = (3,0,2); # oper status : 1:other, 2: Normal, 3: Failure 

# Linux Net-SNMP with LM-SENSORS
my $linux_env_table = "1.3.6.1.4.1.2021.13.16"; # Global env table
my $linux_temp		= "1.3.6.1.4.1.2021.13.16.2.1"; # temperature table
my $linux_temp_descr	= "1.3.6.1.4.1.2021.13.16.2.1.2"; # temperature entry description
my $linux_temp_value	= "1.3.6.1.4.1.2021.13.16.2.1.3"; # temperature entry value (mC)
my $linux_fan		= "1.3.6.1.4.1.2021.13.16.3.1"; # fan table
my $linux_fan_descr	= "1.3.6.1.4.1.2021.13.16.3.1.2"; # fan entry description
my $linux_fan_value	= "1.3.6.1.4.1.2021.13.16.3.1.3"; # fan entry value (RPM)
my $linux_volt		= "1.3.6.1.4.1.2021.13.16.4.1"; # voltage table
my $linux_volt_descr	= "1.3.6.1.4.1.2021.13.16.4.1.2"; # voltage entry description
my $linux_volt_value	= "1.3.6.1.4.1.2021.13.16.4.1.3"; # voltage entry value (mV)
my $linux_misc		= "1.3.6.1.4.1.2021.13.16.5.1"; # misc table
my $linux_misc_descr	= "1.3.6.1.4.1.2021.13.16.5.1.2"; # misc entry description
my $linux_misc_value	= "1.3.6.1.4.1.2021.13.16.5.1.3"; # misc entry value

# Cisco switches (catalys & IOS)
my $cisco_chassis_card_descr	= "1.3.6.1.4.1.9.3.6.11.1.3"; # Chassis card description
my $cisco_chassis_card_slot		= "1.3.6.1.4.1.9.3.6.11.1.7"; # Chassis card slot number
my $cisco_chassis_card_state	= "1.3.6.1.4.1.9.3.6.11.1.9"; # operating status of card 
# 1 : Not specified, 2 : Up, 3: Down, 4 : standby
my @cisco_chassis_card_status_text =("Unknown","Not specified","Up","Down","Standby");
my @cisco_chassis_card_status = (2,2,0,2,0);
my $cisco_module_descr		= "1.3.6.1.2.1.47.1.1.1.1.13"; # Chassis card description
my $cisco_module_slot		= "1.3.6.1.4.1.9.5.1.3.1.1.25"; # Chassis card slot number
my $cisco_module_state		= "1.3.6.1.4.1.9.9.117.1.2.1.1.2"; # operating status of card 
#1:unknown, 2:ok, 3:disabled, 4:okButDiagFailed, 5:boot, 6:selfTest, 7:failed, 8:missing, 9:mismatchWithParent, 10:mismatchConfig, 11:diagFailed, 12:dormant, 13:outOfServiceAdmin, 14:outOfServiceEnvTemp, 15:poweredDown, 16:poweredUp, 17:powerDenied, 18:powerCycled, 19:okButPowerOverWarning, 20:okButPowerOverCritical, 21:syncInProgress
my @cisco_module_status_text =("Unknown", "unknown", "OK", "Disabled", "OkButDiagFailed", "Boot", "SelfTest", "Failed", "Missing", "MismatchWithParent", "MismatchConfig", "DiagFailed", "Dormant", "OutOfServiceAdmin", "OutOfServiceEnvTemp", "PoweredDown", "PoweredUp", "PowerDenied", "PowerCycled", "OkButPowerOverWarning", "OkButPowerOverCritical", "SyncInProgress");
my @cisco_module_status = (3,3,0,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2);

# Juniper routers (JUNOS)
my $juniper_operating_descr	= "1.3.6.1.4.1.2636.3.1.13.1.5"; # Component description
my $juniper_operating_state	= "1.3.6.1.4.1.2636.3.1.13.1.6"; # Operating status of component
# Unknown(1), Running(2), Ready(3), Reset(4), RunningAtFullSpeed(5), Down(6), Standby(7)
my @juniper_operating_status_text =("--Invalid--","Unknown","Running","Ready","Reset","RunningAtFullSpeed","Down","Standby");
my @juniper_operating_status = (3,3,0,0,1,0,2,0);

# Extreme switches
my $extreme_operating_descr	= "1.3.6.1.4.1.1916.1.1.2.2.1.2"; # Component description
my $extreme_operating_state	= "1.3.6.1.4.1.1916.1.1.2.2.1.5"; # Operating status of component
# NotPresent(1), testing(2), mismatch(3), failed(4), operational(5), powerdown(6), unknown(7)
my @extreme_operating_status_text =("--Invalid--","NotPresent","Testing","Mismatch","Failed","Operational","Powerdown","Unknown");
my @extreme_operating_status = (3,0,1,2,2,0,2,3);

# Globals

my $Version='0.5';

my $o_host = 	undef; 		# hostname
my $o_community = undef; 	# community
my $o_port = 	161; 		# port
my $o_help=	undef; 		# wan't some help ?
my $o_verb=	undef;		# verbose mode
my $o_version=	undef;		# print version
my $o_timeout=  undef; 		# Timeout (Default 5)
my $o_perf=     undef;          # Output performance data
my $o_version2= undef;          # use snmp v2c
# check type  
my $o_check_type= "cisco";	 # default Cisco
my @valid_types	=("cisco","nokia","bc","iron","foundry","linux","ciscoSW","extremeSW","juniper");	
my $o_temp=	undef;		# max temp
my $o_fan=	undef;		# min fan speed

# SNMPv3 specific
my $o_login=	undef;		# Login for snmpv3
my $o_passwd=	undef;		# Pass for snmpv3
my $v3protocols=undef;	# V3 protocol list.
my $o_authproto='md5';		# Auth protocol
my $o_privproto='des';		# Priv protocol
my $o_privpass= undef;		# priv password

# functions

sub p_version { print "check_snmp_environment version : $Version (Based on 'check_snmp_env' 1.3 by Patrick Proy)\n"; }


sub print_usage {
    print "Usage: $0 [-v] -H <host> -C <snmp_community> [-2] | (-l login -x passwd [-X pass -L <authp>,<privp>])  [-p <port>] -T (cisco|nokia|bc|iron|foundry|linux|ciscoSW|extremeSW|juniper) [-F <rpm>] [-c <celcius>] [-f] [-t <timeout>] [-V]\n";
}

sub isnnum { # Return true if arg is not a number
  my $num = shift;
  if ( $num =~ /^(\d+\.?\d*)|(^\.\d+)$/ ) { return 0 ;}
  return 1;
}

sub set_status { # return worst status with this order : OK, unknwonw, warning, critical 
  my $new_status=shift;
  my $cur_status=shift;
  if (($cur_status == 0)|| ($new_status==$cur_status)){ return $new_status; }
  if ($new_status==3) { return $cur_status; }
  if ($new_status > $cur_status) {return $new_status;}
  return $cur_status;
}

sub help {
   print "\nSNMP environmental Monitor for Nagios version ",$Version,"\n";
   print "GPL Licence, (c)2006-2007 Patrick Proy\n\n";
   print_usage();
   print <<EOT;
-v, --verbose
   print extra debugging information 
-h, --help
   print this help message
-H, --hostname=HOST
   name or IP address of host to check
-C, --community=COMMUNITY NAME
   community name for the host's SNMP agent (implies v1 protocol)
-2, --v2c
   Use snmp v2c
-l, --login=LOGIN ; -x, --passwd=PASSWD
   Login and auth password for snmpv3 authentication 
   If no priv password exists, implies AuthNoPriv 
-X, --privpass=PASSWD
   Priv password for snmpv3 (AuthPriv protocol)
-L, --protocols=<authproto>,<privproto>
   <authproto> : Authentication protocol (md5|sha : default md5)
   <privproto> : Priv protocole (des|aes : default des) 
-P, --port=PORT
   SNMP port (Default 161)
-T, --type=cisco|nokia|bc|iron|foundry|ciscoSW|extremeSW|juniper
   Environemental check : 
	cisco : All Cisco equipements : voltage,temp,fan,power supply
	        (will try to check everything in the env mib)
	nokia : Nokia IP platforms : fan and power supply
	bc : BlueCoat platforms : fans, power supply, voltage, disks
	iron : IronPort platforms : fans, power supply, temp
	foundry : Foundry Network platforms : power supply, temp
	linux : Net-SNMP with LM-SENSORS : temp, fan, volt, misc
	ciscoSW : Card and module status check on Cisco
	extremeSW : Component status check on Extreme (only tested on BlackDiamond 6808)
	juniper : Component status check on Juniper
-F, --fan=<rpm>
   Minimum fan rpm value (only needed for 'iron' & 'linux')
-c, --celcius=<celcius>
   Maximum temp in degree celcius (only needed for 'iron' & 'linux')
-f, --perfparse
   Perfparse compatible output
-t, --timeout=INTEGER
   timeout for SNMP in seconds (Default: 5)
-V, --version
   prints version number
EOT
}

# For verbose output
sub verb { my $t=shift; print $t,"\n" if defined($o_verb) ; }

sub check_options {
    Getopt::Long::Configure ("bundling");
    GetOptions(
   	'v'	=> \$o_verb,		'verbose'	=> \$o_verb,
        'h'     => \$o_help,    	'help'        	=> \$o_help,
        'H:s'   => \$o_host,		'hostname:s'	=> \$o_host,
        'p:i'   => \$o_port,   		'port:i'	=> \$o_port,
        'C:s'   => \$o_community,	'community:s'	=> \$o_community,
	'l:s'	=> \$o_login,		'login:s'	=> \$o_login,
	'x:s'	=> \$o_passwd,		'passwd:s'	=> \$o_passwd,
	'X:s'	=> \$o_privpass,		'privpass:s'	=> \$o_privpass,
	'L:s'	=> \$v3protocols,		'protocols:s'	=> \$v3protocols,   
        't:i'   => \$o_timeout,       	'timeout:i'     => \$o_timeout,
	'V'	=> \$o_version,		'version'	=> \$o_version,

	'2'     => \$o_version2,        'v2c'           => \$o_version2,
        'f'     => \$o_perf,            'perfparse'     => \$o_perf,
	'T:s'	=> \$o_check_type,	'type:s'	=> \$o_check_type,
        'F:i'   => \$o_fan,             'fan:i'     	=> \$o_fan,
        'c:i'   => \$o_temp,            'celcius:i'     => \$o_temp
	);
    # check the -T option
    my $T_option_valid=0; 
    foreach (@valid_types) { if ($_ eq $o_check_type) {$T_option_valid=1} };
    if ( $T_option_valid == 0 ) 
       {print "Invalid check type (-T)!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
    # Basic checks
	if (defined($o_timeout) && (isnnum($o_timeout) || ($o_timeout < 2) || ($o_timeout > 60))) 
	  { print "Timeout must be >1 and <60 !\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
	if (!defined($o_timeout)) {$o_timeout=5;}
    if (defined ($o_help) ) { help(); exit $ERRORS{"UNKNOWN"}};
    if (defined($o_version)) { p_version(); exit $ERRORS{"UNKNOWN"}};
    if ( ! defined($o_host) ) # check host and filter 
	{ print_usage(); exit $ERRORS{"UNKNOWN"}}
    # check snmp information
    if ( !defined($o_community) && (!defined($o_login) || !defined($o_passwd)) )
	  { print "Put snmp login info!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
	if ((defined($o_login) || defined($o_passwd)) && (defined($o_community) || defined($o_version2)) )
	  { print "Can't mix snmp v1,2c,3 protocols!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
	if (defined ($v3protocols)) {
	  if (!defined($o_login)) { print "Put snmp V3 login info with protocols!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
	  my @v3proto=split(/,/,$v3protocols);
	  if ((defined ($v3proto[0])) && ($v3proto[0] ne "")) {$o_authproto=$v3proto[0];	}	# Auth protocol
	  if (defined ($v3proto[1])) {$o_privproto=$v3proto[1];	}	# Priv  protocol
	  if ((defined ($v3proto[1])) && (!defined($o_privpass))) {
	    print "Put snmp V3 priv login info with priv protocols!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
	}
}

########## MAIN #######

check_options();

# Check gobal timeout if snmp screws up
if (defined($TIMEOUT)) {
  verb("Alarm at $TIMEOUT + 5");
  alarm($TIMEOUT+5);
} else {
  verb("no global timeout defined : $o_timeout + 10");
  alarm ($o_timeout+10);
}

$SIG{'ALRM'} = sub {
 print "No answer from host\n";
 exit $ERRORS{"UNKNOWN"};
};

# Connect to host
my ($session,$error);
if ( defined($o_login) && defined($o_passwd)) {
  # SNMPv3 login
  verb("SNMPv3 login");
    if (!defined ($o_privpass)) {
  verb("SNMPv3 AuthNoPriv login : $o_login, $o_authproto");
    ($session, $error) = Net::SNMP->session(
      -hostname   	=> $o_host,
      -version		=> '3',
      -username		=> $o_login,
      -authpassword	=> $o_passwd,
      -authprotocol	=> $o_authproto,
      -timeout          => $o_timeout
    );  
  } else {
    verb("SNMPv3 AuthPriv login : $o_login, $o_authproto, $o_privproto");
    ($session, $error) = Net::SNMP->session(
      -hostname   	=> $o_host,
      -version		=> '3',
      -username		=> $o_login,
      -authpassword	=> $o_passwd,
      -authprotocol	=> $o_authproto,
      -privpassword	=> $o_privpass,
	  -privprotocol => $o_privproto,
      -timeout          => $o_timeout
    );
  }
} else {
	if (defined ($o_version2)) {
		# SNMPv2 Login
		verb("SNMP v2c login");
		  ($session, $error) = Net::SNMP->session(
		 -hostname  => $o_host,
		 -version   => 2,
		 -community => $o_community,
		 -port      => $o_port,
		 -timeout   => $o_timeout
		);
  	} else {
	  # SNMPV1 login
	  verb("SNMP v1 login");
	  ($session, $error) = Net::SNMP->session(
		-hostname  => $o_host,
		-community => $o_community,
		-port      => $o_port,
		-timeout   => $o_timeout
	  );
	}
}
if (!defined($session)) {
   printf("ERROR opening session: %s.\n", $error);
   exit $ERRORS{"UNKNOWN"};
}

my $exit_val=undef;
########### Cisco env checks ##############

if ($o_check_type eq "cisco") {

verb("Checking cisco env");

# Get load table
my $resultat = (Net::SNMP->VERSION < 4) ? 
		  $session->get_table($ciscoEnvMonMIB)
		: $session->get_table(Baseoid => $ciscoEnvMonMIB); 
		
if (!defined($resultat)) {
   printf("ERROR: Description table : %s.\n", $session->error);
   $session->close;
   exit $ERRORS{"UNKNOWN"};
}
$session->close;

# Get env data index
my (@voltindex,@tempindex,@fanindex,@psindex)=(undef,undef,undef,undef);
my ($voltexist,$tempexist,$fanexist,$psexist)=(0,0,0,0);
my @oid=undef;
foreach my $key ( keys %$resultat) {
   verb("OID : $key, Desc : $$resultat{$key}");
   if ( $key =~ /$ciscoVoltageTableDesc/ ) { 
      @oid=split (/\./,$key);
      $voltindex[$voltexist++] = pop(@oid);
   }
   if ( $key =~ /$ciscoTempTableDesc/ ) { 
      @oid=split (/\./,$key);
      $tempindex[$tempexist++] = pop(@oid);
   }
   if ( $key =~ /$ciscoFanTableDesc/ ) { 
      @oid=split (/\./,$key);
      $fanindex[$fanexist++] = pop(@oid);
   }
   if ( $key =~ /$ciscoPSTableDesc/ ) { 
      @oid=split (/\./,$key);
      $psindex[$psexist++] = pop(@oid);
   }
}

if ( ($voltexist ==0) && ($tempexist ==0) && ($fanexist ==0) && ($psexist ==0) ) {
  print "No Environemental data found : UNKNOWN";
  exit $ERRORS{"UNKNOWN"};
}

my $perf_output="";
# Get the data
my ($i,$cur_status)=(undef,undef); 

my $volt_global=0;
my %volt_status;
if ($fanexist !=0) {
  for ($i=0;$i < $voltexist; $i++) {
    $cur_status=$$resultat{$ciscoVoltageTableState. "." . $voltindex[$i]};
    verb ($$resultat{$ciscoVoltageTableDesc .".".$voltindex[$i]});
    verb ($cur_status);
    if (!defined ($cur_status)) { ### Error TODO
      $volt_global=1;
    } 
    if (defined($$resultat{$ciscoVoltageTableValue."." . $voltindex[$i]})) {
      $perf_output.=" '".$$resultat{$ciscoVoltageTableDesc .".".$voltindex[$i]}."'=" ;
      $perf_output.=$$resultat{$ciscoVoltageTableValue."." . $voltindex[$i]};
    }	
    if ($Nagios_state[$CiscoEnvMonNagios{$cur_status}] ne "OK") {
      $volt_global= 1;
      $volt_status{$$resultat{$ciscoVoltageTableDesc .".".$voltindex[$i]}}=$cur_status;
    }
  }
}


my $temp_global=0;
my %temp_status;
if ($tempexist !=0) {
  for ($i=0;$i < $tempexist; $i++) {
    $cur_status=$$resultat{$ciscoTempTableState . "." . $tempindex[$i]};
    verb ($$resultat{$ciscoTempTableDesc .".".$tempindex[$i]});
    verb ($cur_status);
    if (!defined ($cur_status)) { ### Error TODO
      $temp_global=1;
    }
    if (defined($$resultat{$ciscoTempTableValue."." . $tempindex[$i]})) {
      $perf_output.=" '".$$resultat{$ciscoTempTableDesc .".".$tempindex[$i]}."'=" ;
      $perf_output.=$$resultat{$ciscoTempTableValue."." . $tempindex[$i]};
    }
    if ($Nagios_state[$CiscoEnvMonNagios{$cur_status}] ne "OK") {
      $temp_global= 1;
      $temp_status{$$resultat{$ciscoTempTableDesc .".".$tempindex[$i]}}=$cur_status;
    }
  }
}

                
my $fan_global=0;
my %fan_status;
if ($fanexist !=0) {
  for ($i=0;$i < $fanexist; $i++) {
    $cur_status=$$resultat{$ciscoFanTableState . "." . $fanindex[$i]};
    verb ($$resultat{$ciscoFanTableDesc .".".$fanindex[$i]});
    verb ($cur_status);
    if (!defined ($cur_status)) { ### Error TODO
      $fan_global=1;
    }
    if ($Nagios_state[$CiscoEnvMonNagios{$cur_status}] ne "OK") {
      $fan_global= 1;
      $fan_status{$$resultat{$ciscoFanTableDesc .".".$fanindex[$i]}}=$cur_status;
    }
  }
}

my $ps_global=0;
my %ps_status;
if ($psexist !=0) {
  for ($i=0;$i < $psexist; $i++) {
    $cur_status=$$resultat{$ciscoPSTableState . "." . $psindex[$i]};
    if (!defined ($cur_status)) { ### Error TODO
      $fan_global=1;
    }
    if ($Nagios_state[$CiscoEnvMonNagios{$cur_status}] ne "OK") {
      $ps_global= 1;
      $ps_status{$$resultat{$ciscoPSTableDesc .".".$psindex[$i]}}=$cur_status;
    }
  }
}

my $global_state=0; 
my $output="";

if ($fanexist !=0) {
	if ($fan_global ==0) {
	   $output .= $fanexist." Fan OK";
	   $global_state=1 if ($global_state==0);
	} else {
	  foreach (keys %fan_status) {
	    $output .= "Fan " . $_ . ":" . $CiscoEnvMonState {$fan_status{$_}} ." ";
		if ($global_state < $CiscoEnvMonNagios{$fan_status{$_}} ) {
		  $global_state = $CiscoEnvMonNagios{$fan_status{$_}} ;
		}
	  }
	}
}

if ($psexist !=0) {
	$output .= ", " if ($output ne "");
	if ($ps_global ==0) {
	   $output .= $psexist." ps OK";
	   $global_state=1 if ($global_state==0);
	} else {
	  foreach (keys %ps_status) {
	    $output .= "ps " . $_ . ":" . $CiscoEnvMonState {$ps_status{$_}} ." ";
		if ($global_state < $CiscoEnvMonNagios{$ps_status{$_}} ) {
		  $global_state = $CiscoEnvMonNagios{$ps_status{$_}} ;
		}
	  }
	}
}

if ($voltexist !=0) {
	$output .= ", " if ($output ne "");
	if ($volt_global ==0) {
	   $output .= $voltexist." volt OK";
	   $global_state=1 if ($global_state==0);
	} else {
	  foreach (keys %volt_status) {
	    $output .= "volt " . $_ . ":" . $CiscoEnvMonState {$volt_status{$_}} ." ";
		if ($global_state < $CiscoEnvMonNagios{$volt_status{$_}} ) {
		  $global_state = $CiscoEnvMonNagios{$volt_status{$_}} ;
		}
	  }
	}
}

if ($tempexist !=0) {
	$output .= ", " if ($output ne "");
	if ($temp_global ==0) {
	   $output .= $tempexist." temp OK";
	   $global_state=1 if ($global_state==0);
	} else {
	  foreach (keys %temp_status) {
	    $output .= "temp " . $_ . ":" . $CiscoEnvMonState {$temp_status{$_}} ." ";
		if ($global_state < $CiscoEnvMonNagios{$temp_status{$_}} ) {
		  $global_state = $CiscoEnvMonNagios{$temp_status{$_}} ;
		}
	  }
	}
}

#print $output," : ",$Nagios_state[$global_state]," | ",$perf_output,"\n";
print $output," : ",$Nagios_state[$global_state],"\n";
$exit_val=$ERRORS{$Nagios_state[$global_state]};

exit $exit_val;

}

############# Nokia checks
if ($o_check_type eq "nokia") {

verb("Checking nokia env");

my $resultat;
# status : 0=ok, 1=nok, 2=temp prb
my ($fan_status,$ps_status,$temp_status)=(0,0,0);
my ($fan_exist,$ps_exist,$temp_exist)=(0,0,0);
my ($num_fan,$num_ps)=(0,0);
my ($num_fan_nok,$num_ps_nok)=(0,0);
my $global_status=0;
my $output="";
# get temp
$resultat = (Net::SNMP->VERSION < 4) ? 
		  $session->get_table($nokia_temp_tbl)
		: $session->get_table(Baseoid => $nokia_temp_tbl); 
if (defined($resultat)) {
  verb ("temp found");
  $temp_exist=1;
  if ($$resultat{$nokia_temp} != 1) { 
    $temp_status=2;$global_status=1;
	$output="Temp CRITICAL ";
  } else {
    $output="Temp OK ";
  }
}
		
# Get fan table
$resultat = (Net::SNMP->VERSION < 4) ? 
		  $session->get_table($nokia_fan_table)
		: $session->get_table(Baseoid => $nokia_fan_table); 
		
if (defined($resultat)) {
  $fan_exist=1;
  foreach my $key ( keys %$resultat) {
    verb("OID : $key, Desc : $$resultat{$key}");
    if ( $key =~ /$nokia_fan_status/ ) { 
      if ($$resultat{$key} != 1) { $fan_status=1; $num_fan_nok++}      
	  $num_fan++;
    }
  }
  if ($fan_status==0) {
    $output.= ", ".$num_fan." fan OK";
  } else {
    $output.= ", ".$num_fan_nok."/".$num_fan." fan CRITICAL";
	$global_status=2;
  }
}

# Get ps table
$resultat = (Net::SNMP->VERSION < 4) ? 
		  $session->get_table($nokia_ps_table)
		: $session->get_table(Baseoid => $nokia_ps_table); 
		
if (defined($resultat)) {
  $ps_exist=1;
  foreach my $key ( keys %$resultat) {
    verb("OID : $key, Desc : $$resultat{$key}");
    if ( $key =~ /$nokia_ps_status/ ) { 
      if ($$resultat{$key} != 1) { $ps_status=1; $num_ps_nok++;}      
	  $num_ps++;
    }
    if ( $key =~ /$nokia_ps_temp/ ) { 
      if ($$resultat{$key} != 1) { if ($ps_status==0) {$ps_status=2;$num_ps_nok++;} }      
    }	
  }
  if ($ps_status==0) {
    $output.= ", ".$num_ps." ps OK";
  } elsif ($ps_status==2) {
    $output.= ", ".$num_ps_nok."/".$num_ps." ps WARNING (temp)";
	if ($global_status != 2) {$global_status=1;}
  } else {
    $output.= ", ".$num_ps_nok."/".$num_ps." ps CRITICAL";
	$global_status=2;
  }
}

$session->close;

verb ("status : $global_status");

if ( ($fan_exist+$ps_exist+$temp_exist) == 0) {
  print "No environemental informations found : UNKNOWN\n";
  exit $ERRORS{"UNKNOWN"};
}

if ($global_status==0) {
  print $output." : all OK\n";
  exit $ERRORS{"OK"};
}

if ($global_status==1) {
  print $output." : WARNING\n";
  exit $ERRORS{"WARNING"};
}

if ($global_status==2) {
  print $output." : CRITICAL\n";
  exit $ERRORS{"CRITICAL"};
}
}

############# Bluecoat checks
if ($o_check_type eq "bc") {

	verb("Checking bluecoat env");

	my $resultat;
	my $global_status=0;
	my ($num_fan,$num_other,$num_volt,$num_temp,$num_disk)=(0,0,0,0,0);
	my ($num_fan_ok,$num_other_ok,$num_volt_ok,$num_temp_ok,$num_disk_ok)=(0,0,0,0,0);
	my $output="";
	my $output_perf="";


	# get sensor table
	$resultat = (Net::SNMP->VERSION < 4) ? 
			  $session->get_table($bc_sensor_table)
			: $session->get_table(Baseoid => $bc_sensor_table); 
	if (defined($resultat)) {
		verb ("sensor table found");
		my ($sens_name,$sens_status,$sens_value,$sens_unit)=(undef,undef,undef,undef);
		foreach my $key ( keys %$resultat) {
			if ($key =~ /$bc_sensor_Name/) { 
				$sens_name = $$resultat{$key};
				$key =~ s/$bc_sensor_Name//;
				$sens_unit = $$resultat{$bc_sensor_units.$key};
				if ($$resultat{$bc_sensor_Status.$key} != 1) { # sensor not operating : output and status unknown
					if ($output ne "") { $output.=", ";}
					$output .= $sens_name ." sensor ".$bc_SensorStatus[$$resultat{$bc_sensor_Status.$key}];
					if ($global_status==0) {$global_status=3;}
				} else { # Get status
					$sens_status=$bc_status_nagios[$$resultat{$bc_sensor_Code.$key}];
					if ($sens_status != 0) { # warn/critical/unknown : output
						if ($output ne "") { $output.=", ";}
						$output .= $sens_name . ":".$bc_SensorCode[$sens_status];
						set_status($sens_status,$global_status);			
					}
				}
				if (defined($o_perf)) {
					if ($output_perf ne "") { $output_perf .=" ";}
					$output_perf .= "'".$sens_name."'=";
					my $perf_value = $$resultat{$bc_sensor_Value.$key} * 10 ** $$resultat{$bc_sensor_Scale.$key};
					$output_perf .= $perf_value;
				}
				### FAN
				if ($bc_mesure[$sens_unit] eq "rpm") { 
					$num_fan++;if ($sens_status == 0) { $num_fan_ok++; }
				} elsif ($bc_mesure[$sens_unit] eq "celsius") { 
					$num_fan++;if ($sens_status == 0) { $num_temp_ok++; }
				} elsif ($bc_mesure[$sens_unit] eq "volts") { 
					$num_volt++;if ($sens_status == 0) { $num_volt_ok++; }
				} else { 
					$num_other++;if ($sens_status == 0) { $num_other_ok++;}}
			}
		} 
	}
			
	# Get disk table
	$resultat = (Net::SNMP->VERSION < 4) ? 
			  $session->get_table($bc_dsk_table)
			: $session->get_table(Baseoid => $bc_dsk_table); 
			
	if (defined($resultat)) {
		foreach my $key ( keys %$resultat) {
		    verb("OID : $key, Desc : $$resultat{$key}");
			my ($dsk_name,$dsk_status)=(undef,undef,undef);
		    if ( $key =~ /$bc_dsk_status/ ) {
				$num_disk++;
				$dsk_status=$bc_dsk_status_nagios[$$resultat{$key}];
				if ( $dsk_status != 0) {
					$key =~ s/$bc_dsk_status//;
					$dsk_name = $$resultat{$bc_dsk_vendor.$key} . "(".$$resultat{$bc_dsk_serial.$key} . ")";
					if ($output ne "") { $output.=", ";}
					$output .= $dsk_name . ":" . $bc_DiskStatus[$$resultat{$bc_dsk_status.$key}];
					set_status($dsk_status,$global_status);	
				} else {      
					$num_disk_ok++;
				}
			}
		}
	}

	if ($num_fan+$num_other+$num_volt+$num_temp+$num_disk == 0) {
	  print "No information found : UNKNOWN\n";
	  exit $ERRORS{"UNKNOWN"};
	}

	if ($output ne "") { $output.=", ";}
	if ($num_fan_ok != 0) { $output.= $num_fan_ok." fan OK ";}
	if ($num_other_ok != 0) { $output.= $num_other_ok." other OK ";}
	if ($num_volt_ok != 0) { $output.= $num_volt_ok." voltage OK ";}
	if ($num_temp_ok != 0) { $output.= $num_temp_ok." temp OK ";}
	if ($num_disk_ok != 0) { $output.= $num_disk_ok." disk OK ";}

	if (defined($o_perf)) { $output_perf = " | " . $output_perf;}
	if ($global_status==3) {
	  print $output," : UNKNOWN",$output_perf,"\n";
	  exit $ERRORS{"UNKNOWN"};
	}
	if ($global_status==2) {
	  print $output," : CRITICAL",$output_perf,"\n";
	  exit $ERRORS{"CRITICAL"};
	}
	if ($global_status==1) {
	  print $output," : WARNING",$output_perf,"\n";
	  exit $ERRORS{"WARNING"};
	}
	print $output," : OK",$output_perf,"\n";
	exit $ERRORS{"OK"};

}


############# Ironport checks
if ($o_check_type eq "iron") {

verb("Checking Ironport env");

my $resultat;
# status : 0=ok, 1=warn, 2=crit
my ($fan_status,$ps_status,$temp_status)=(0,0,0);
my ($fan_exist,$ps_exist,$temp_exist)=(0,0,0);
my ($num_fan,$num_ps,$num_temp)=(0,0,0);
my ($num_fan_nok,$num_ps_nok,$num_temp_nok)=(0,0,0);
my $global_status=0;
my $output="";
# get temp if $o_temp is defined
if (defined($o_temp)) {
  verb("Checking temp < $o_temp");
  $resultat = (Net::SNMP->VERSION < 4) ? 
		  $session->get_table($iron_tmp_table)
		: $session->get_table(Baseoid => $iron_tmp_table); 
  if (defined($resultat)) {
    verb ("temp found");
    $temp_exist=1;
    foreach my $key ( keys %$resultat) {
      verb("OID : $key, Desc : $$resultat{$key}");
      if ( $key =~ /$iron_tmp_celcius/ ) {
	verb("Status : $$resultat{$key}");
        if ($$resultat{$key} > $o_temp) { 
  	  my @index_oid=split(/\./,$key);
	  my $index_oid_key=pop(@index_oid);
          $output .= ",Temp : ". $$resultat{ $iron_tmp_name.".".$index_oid_key}." : ".$$resultat{$key}." C";
	  $temp_status=2;
	  $num_temp_nok++;
	}
        $num_temp++;
      }
    }
    if ($temp_status==0) {
      $output.= ", ".$num_temp." temp < ".$o_temp." OK";
    } else {
      $output.= ", ".$num_temp_nok."/".$num_temp." temp probes CRITICAL";
      $global_status=2;
    }
  }
}

# Get fan status if $o_fan is defined
if (defined($o_fan)) {
  verb("Checking fan > $o_fan");
  $resultat = (Net::SNMP->VERSION < 4) ?
                  $session->get_table($iron_fan_table)
                : $session->get_table(Baseoid => $iron_fan_table);
  if (defined($resultat)) {
    verb ("fan found");
    $fan_exist=1;
    foreach my $key ( keys %$resultat) {
      verb("OID : $key, Desc : $$resultat{$key}");
      if ( $key =~ /$iron_fan_rpm/ ) {
	verb("Status : $$resultat{$key}");
        if ($$resultat{$key} < $o_fan) {
  	  my @index_oid=split(/\./,$key);
	  my $index_oid_key=pop(@index_oid);
          $output .= ",Fan ". $$resultat{ $iron_fan_name.".".$index_oid_key}." : ".$$resultat{$key}." RPM";
          $fan_status=2;
          $num_fan_nok++;
	}
        $num_fan++;
      }
    }
    if ($fan_status==0) {
      $output.= ", ".$num_fan." fan > ".$o_fan." OK";
    } else {
      $output.= ", ".$num_fan_nok."/".$num_fan." fans CRITICAL";
      $global_status=2;
    }
  }
}

# Get power supply status
  verb("Checking PS");
  $resultat = (Net::SNMP->VERSION < 4) ?
                  $session->get_table($iron_ps_table)
                : $session->get_table(Baseoid => $iron_ps_table);
  if (defined($resultat)) {
    verb ("ps found");
    $ps_exist=1;
    foreach my $key ( keys %$resultat) {
      verb("OID : $key, Desc : $$resultat{$key}");
      if ( $key =~ /$iron_ps_status/ ) {
	verb("Status : $iron_ps_status_name[$$resultat{$key}]");
        if ($iron_ps_status_nagios[$$resultat{$key}] != 0) {
  	  my @index_oid=split(/\./,$key);
	  my $index_oid_key=pop(@index_oid);
          $output .= ",PS ". $$resultat{$iron_ps_name.".".$index_oid_key}." : ".$iron_ps_status_name[$$resultat{$key}];
          $ps_status=2;
          $num_ps_nok++;
	}
        $num_ps++;
      }
    }
    if ($ps_status==0) {
      $output.= ", ".$num_ps." ps OK";
    } else {
      $output.= ", ".$num_ps_nok."/".$num_ps." ps CRITICAL";
      $global_status=2;
    }
  }

$session->close;

verb ("status : $global_status");

if ( ($fan_exist+$ps_exist+$temp_exist) == 0) {
  print "No environemental informations found : UNKNOWN\n";
  exit $ERRORS{"UNKNOWN"};
}

$output =~ s/^,//;

if ($global_status==0) {
  print $output." : all OK\n";
  exit $ERRORS{"OK"};
}

if ($global_status==1) {
  print $output." : WARNING\n";
  exit $ERRORS{"WARNING"};
}

if ($global_status==2) {
  print $output." : CRITICAL\n";
  exit $ERRORS{"CRITICAL"};
}
}


########### Foundry env checks ##############

if ($o_check_type eq "foundry") {

verb("Checking foundry env");

my $global_status=0; # status to UNKNOWN
my $output="";

# Get temperature

my @foundry_temp_oid=($foundry_temp,$foundry_temp_warn,$foundry_temp_crit);

my $result_temp = $session->get_request(
   Varbindlist => \@foundry_temp_oid
);

my $temp_found=0;
if (defined($result_temp)) {
  $temp_found=1;
  #Temp found
  $output = "Temp : " . $$result_temp{$foundry_temp} / 2;
  if ($$result_temp{$foundry_temp} > $$result_temp{$foundry_temp_crit}) { # Temp above critical
    $output.= " > ". $$result_temp{$foundry_temp_crit} / 2 . " : CRITICAL";
    $global_status=3;
  } elsif ( $$result_temp{$foundry_temp} > $$result_temp{$foundry_temp_warn}) { # Temp above warning
      $output.= " > ". $$result_temp{$foundry_temp_warn} / 2 . " : WARNING";
      $global_status=2;
  } else {
      $output.= " < ". $$result_temp{$foundry_temp_warn} / 2 . " : OK";
      $global_status=1;
  }
}

# Get PS table (TODO : Bug in FAN table, see with Foundry).

my $result_ps = (Net::SNMP->VERSION < 4) ? 
                    $session->get_table($foundry_ps_table)
                  : $session->get_table(Baseoid => $foundry_ps_table);

my $ps_num=0;
if (defined($result_ps)) {
  $output .=", " if defined($output);
  foreach my $key ( keys %$result_ps) {
    verb("OID : $key, Desc : $$result_ps{$key}");
    if ($$result_ps{$key} =~ /$foundry_ps_desc/) {
     $ps_num++;
     my @oid_list = split (/\./,$key); 
     my $index_ps = pop (@oid_list); 
     $index_ps= $foundry_ps_status . "." . $index_ps;
     if (defined ($$result_ps{$index_ps})) {
        if ($$result_ps{$index_ps} == 3) {
	  $output.="PS ".$$result_ps{$key}." : FAILURE";
          $global_status=3;
        } elsif ($$result_ps{$index_ps} == 2) {
  	  $global_status=1 if ($global_status==0);
        } else {
          $output.= "ps ".$$result_ps{$key}." : OTHER";
        }
     } else {
       $output.= "ps ".$$result_ps{$key}." : UNDEFINED STATUS";    
     } 
   }
 }
}

$session->close;

if (($ps_num+$temp_found) == 0) {
  print  "No data found : UNKNOWN\n";
  exit $ERRORS{"UNKNOWN"};
}

if ($global_status==1) {
  print $output." : all OK\n";
  exit $ERRORS{"OK"};
}

if ($global_status==2) {
  print $output." : WARNING\n";
  exit $ERRORS{"WARNING"};
}

if ($global_status==3) {
  print $output." : CRITICAL\n";
  exit $ERRORS{"CRITICAL"};
}

print  $output." : UNKNOWN\n";
exit $ERRORS{"UNKNOWN"};

}

########### Linux env checks ##############
if ($o_check_type eq "linux") {

	verb("Checking linux env");

	my $output="";

 	# get sensor table
	my $resultat = (Net::SNMP->VERSION < 4) ? 
			  $session->get_table($linux_env_table)
			: $session->get_table(Baseoid => $linux_env_table); 
	if (!defined($resultat)) {
		print "Cannot get card/module information : UNKNOWN\n";
		exit $ERRORS{"UNKNOWN"};
	}
	
	verb ("sensor table found");
	
	my ($sens_name,$sens_status,$sens_value,$sens_unit)=(undef,undef,undef,undef);
	my $index;
	foreach my $key ( keys %$resultat) {
		if ($key =~ /$linux_temp_descr/) {
			$sens_name=$$resultat{$key};
			$index=(split /\./,$key)[-1];
			$sens_value=$$resultat{$linux_temp_value.".".$index}/1000;
			printf("TSensor %s : %.0f\n",$sens_name,$sens_value);
		}
		if ($key =~ /$linux_fan_descr/) {
			$sens_name=$$resultat{$key};
			$index=(split /\./,$key)[-1];
			$sens_value=$$resultat{$linux_fan_value.".".$index};
			printf("FSensor %s : %.0f\n",$sens_name,$sens_value);
		}
		if ($key =~ /$linux_volt_descr/) {
			$sens_name=$$resultat{$key};
			$index=(split /\./,$key)[-1];
			$sens_value=$$resultat{$linux_volt_value.".".$index}/1000;
			printf("VSensor %s : %.2f\n",$sens_name,$sens_value);
		}				
		if ($key =~ /$linux_misc_descr/) {
			$sens_name=$$resultat{$key};
			$index=(split /\./,$key)[-1];
			$sens_value=$$resultat{$linux_misc_value.".".$index};
			printf("MSensor %s : %.2f\n",$sens_name,$sens_value);
		}				
	}
	
	print "Not implemented yet : UNKNOWN\n";
	exit $ERRORS{"UNKNOWN"};
}

########### Cisco switch 6XXX and 4XXX card status checks ##############

if ($o_check_type eq "ciscoSW") {

	verb("Checking ciscoSW env");

	my $global_status=0; # status to UNKNOWN
	my $output="";

	# Get cards a modules status

	my @ciscoSW_oid=($cisco_chassis_card_state,$cisco_module_state);

	# get card & module table
	my $resultat_c =  $session->get_table(Baseoid => $cisco_chassis_card_state);
	my $resultat_m =  $session->get_table(Baseoid => $cisco_module_state);
			
	my $final_status=0;
	my $tmp_status;
	my ($num_cards,$num_cards_ok,$num_modules,$num_modules_ok)=(0,0,0,0);
	my $card_output="";
	my $modules_output="";
	my $result_t;
	my $index;
	my @temp_oid;

	if (defined($resultat_c)) {	
		foreach my $key ( keys %$resultat_c) {
			if ($key =~ /$cisco_chassis_card_state/) {
				$num_cards++;
				$tmp_status=$cisco_chassis_card_status[$$resultat_c{$key}];
				if ($tmp_status == 0) {
					$num_cards_ok++;
				} else {
					$final_status=2;
					$index=(split /\./,$key)[-1];
					@temp_oid=($cisco_chassis_card_descr.".".$index,$cisco_chassis_card_slot.".".$index);
					$result_t = $session->get_request( Varbindlist => \@temp_oid);				
					if (!defined($result_t)) { $card_output.="Invalid card(UNKNOWN)";}
					else {
						if ($card_output ne "") {$card_output.=", ";}
						$card_output.= "Card slot " . $$result_t{$cisco_chassis_card_slot.".".$index};
						$card_output.= "(" .$$result_t{$cisco_chassis_card_descr.".".$index} ."): "; 
						$card_output.= "status " . $cisco_chassis_card_status_text[$$resultat_c{$key}];
					}
				}
			}
		}
		if ($card_output ne "") {$card_output.=", ";}
	}

	if (defined($resultat_m)) {
		foreach my $key ( keys %$resultat_m) {
			if ($key =~ /$cisco_module_state/) {
				$num_modules++;
				$tmp_status=$cisco_module_status[$$resultat_m{$key}];
				if ($tmp_status == 0) {
					$num_modules_ok++;
				} else {
					my $module_slot_present=0;
					$index=(split /\./,$key)[-1];
					@temp_oid=($cisco_module_slot.".".$index);
                                        $result_t = $session->get_request( Varbindlist => \@temp_oid);
                                        if (defined($result_t)) { 
                                                if ($modules_output ne "") {$modules_output.=", ";}
                                                $modules_output.= "Module slot " . $$result_t{$cisco_module_slot.".".$index};
						$module_slot_present=1;
					}					
					@temp_oid=($cisco_module_descr.".".$index);
					$result_t = $session->get_request( Varbindlist => \@temp_oid);				
					if (defined($result_t)) {
						if ($module_slot_present == 1) {
							$modules_output.= "(" .$$result_t{$cisco_module_descr.".".$index} ."): "; 
						} else {
							if ($modules_output ne "") {$modules_output.=", ";}
							$modules_output.= "Module (" .$$result_t{$cisco_module_descr.".".$index} ."): ";
						}
						$modules_output.= "status " . $cisco_module_status_text[$$resultat_m{$key}];
					 	$module_slot_present=1;	
					}
					if ($module_slot_present == 0) {
						$modules_output.="Invalid module(UNKNOWN) : status " . $cisco_module_status_text[$$resultat_m{$key}];
					}
					if ($tmp_status == 1 && $final_status==0) {
						$final_status=1;
					} else {
						$final_status=2;
					}
				}
			}
		}
	}

	$session->close;
	if ($num_cards==0 && $num_modules==0) {
		print "No cards/modules found : UNKNOWN\n";
		exit $ERRORS{"UNKNOWN"};
	}
	$output=$card_output . $modules_output;
	if ($output ne "") {$output.=" : ";}
	if ($num_cards!=0) {
		if ($num_cards == $num_cards_ok) {
		  $output.= $num_cards . " cards OK, ";
		} else {
		  $output.= $num_cards_ok . "/" . $num_cards ." cards OK, ";
		  $final_status=2;
		}
	}

	if ($num_modules!=0) {
		if ($num_modules == $num_modules_ok) {
		  $output.= $num_modules . " modules OK ";
		} else {
		  $output.= $num_modules_ok . "/" . $num_modules ." modules OK ";
		  $final_status=2;
		}
	}
	
	if ($final_status == 2) {
		print $output," : CRITICAL\n";
		exit $ERRORS{"CRITICAL"};
	}

	if ($final_status == 1) {
		print $output," : WARNING\n";
		exit $ERRORS{"WARNING"};
	}
	
	print $output," : OK\n";
	exit $ERRORS{"OK"};

}


########### Juniper router status checks ##############

if ($o_check_type eq "juniper") {

	verb("Checking juniper env");

	my $global_status=0; # status to UNKNOWN
	my $output="";

	# Get components status
	my @juniper_oid=($juniper_operating_state);

	# get component table
	my $resultat_c =  $session->get_table(Baseoid => $juniper_operating_state);
			
	my $final_status=0;
	my $tmp_status;
	my ($num_cards,$num_cards_ok)=(0,0);
	my $card_output="";
	my $ignore="";
	my $result_t;
	my $index;
	my @temp_oid;

	if (defined($resultat_c)) {	
		foreach my $key ( keys %$resultat_c) {
			if ($key =~ /$juniper_operating_state/) {
				$num_cards++;
				$tmp_status=$juniper_operating_status[$$resultat_c{$key}];
				if ($tmp_status == 0) {
					$num_cards_ok++;
				} else {
					$index = $key;
					$index =~ s/^$juniper_operating_state.//;
					@temp_oid=($juniper_operating_descr.".".$index);
					$result_t = $session->get_request( Varbindlist => \@temp_oid);	
					if ($$result_t{$juniper_operating_descr.".".$index} =~ /PCMCIA|USB/ && $tmp_status == 3) {
							$ignore.= ": Ignored " . $juniper_operating_status_text[$$resultat_c{$key}];
							$ignore.= "(" .$$result_t{$juniper_operating_descr.".".$index} .")"; 
					}
					else {
						if ($tmp_status == 1 && $final_status != 2) {
							$final_status=$tmp_status;
						}
						if ($tmp_status == 2) {
							$final_status=$tmp_status;
						}
						if ($tmp_status == 3 && $final_status == 0) {
							$final_status=$tmp_status;
						}			
						if (!defined($result_t)) { 
							$card_output.="Invalid component(UNKNOWN)";
						}
						else {
							if ($card_output ne "") {$card_output.=", ";}
							$card_output.= "(" .$$result_t{$juniper_operating_descr.".".$index} ."): "; 
							$card_output.= "status " . $juniper_operating_status_text[$$resultat_c{$key}];
						}
					}
				}
			}
		}
		if ($card_output ne "") {$card_output.=", ";}
	}

	$session->close;
	if ($num_cards==0) {
		print "No components found : UNKNOWN\n";
		exit $ERRORS{"UNKNOWN"};
	}
	$output=$card_output;
	if ($output ne "") {$output.=" : ";}
	if ($num_cards!=0) {
		if ($num_cards == $num_cards_ok) {
		  $output.= $num_cards . " components OK";
		} else {
		  $output.= $num_cards_ok . "/" . $num_cards ." components OK" .$ignore;
		}
	}

	if ($final_status == 3) {
		print $output," : UNKNOWN\n";
		exit $ERRORS{"UNKNOWN"};
	}
	
	if ($final_status == 2) {
		print $output," : CRITICAL\n";
		exit $ERRORS{"CRITICAL"};
	}

	if ($final_status == 1) {
		print $output," : WARNING\n";
		exit $ERRORS{"WARNING"};
	}
	
	print $output," : OK\n";
	exit $ERRORS{"OK"};

}

########### Extreme switches status checks ##############

if ($o_check_type eq "extremeSW") {

	verb("Checking extreme env");

	my $global_status=0; # status to UNKNOWN
	my $output="";

	# Get components status
	my @extreme_oid=($extreme_operating_state);

	# get component table
	my $resultat_c =  $session->get_table(Baseoid => $extreme_operating_state);
			
	my $final_status=0;
	my $tmp_status;
	my ($num_cards,$num_cards_ok)=(0,0);
	my $card_output="";
	my $ignore="";
	my $result_t;
	my $index;
	my @temp_oid;

	if (defined($resultat_c)) {	
		foreach my $key ( keys %$resultat_c) {
			if ($key =~ /$extreme_operating_state/) {
				if ($$resultat_c{$key} != 1) {
					$num_cards++;
					$tmp_status=$extreme_operating_status[$$resultat_c{$key}];
					if ($tmp_status == 0) {
						$num_cards_ok++;
					} else {
						$index = $key;
						$index =~ s/^$extreme_operating_state.//;
						@temp_oid=($extreme_operating_descr.".".$index);
						$result_t = $session->get_request( Varbindlist => \@temp_oid);	
						if ($tmp_status == 1 && $final_status != 2) {
							$final_status=$tmp_status;
						}
						if ($tmp_status == 2) {
							$final_status=$tmp_status;
						}
						if ($tmp_status == 3 && $final_status == 0) {
							$final_status=$tmp_status;
						}			
						if (!defined($result_t)) { 
							$card_output.="Invalid module(UNKNOWN)";
						}
						else {
							if ($card_output ne "") {$card_output.=", ";}
							$card_output.= "(Module: " .$$result_t{$extreme_operating_descr.".".$index} ."): "; 
							$card_output.= "status " . $extreme_operating_status_text[$$resultat_c{$key}];
						}
					}
				}
			}
		}
		if ($card_output ne "") {$card_output.=", ";}
	}

	$session->close;
	if ($num_cards==0) {
		print "No modules found : UNKNOWN\n";
		exit $ERRORS{"UNKNOWN"};
	}
	$output=$card_output;
	if ($output ne "") {$output.=" : ";}
	if ($num_cards!=0) {
		if ($num_cards == $num_cards_ok) {
		  $output.= $num_cards . " modules OK";
		} else {
		  $output.= $num_cards_ok . "/" . $num_cards ." modules OK" .$ignore;
		}
	}

	if ($final_status == 3) {
		print $output," : UNKNOWN\n";
		exit $ERRORS{"UNKNOWN"};
	}
	
	if ($final_status == 2) {
		print $output," : CRITICAL\n";
		exit $ERRORS{"CRITICAL"};
	}

	if ($final_status == 1) {
		print $output," : WARNING\n";
		exit $ERRORS{"WARNING"};
	}
	
	print $output," : OK\n";
	exit $ERRORS{"OK"};

}

print "Unknown check type : UNKNOWN\n";
exit $ERRORS{"UNKNOWN"};
