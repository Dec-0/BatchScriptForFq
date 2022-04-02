#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use File::Basename;

my ($HelpFlag,$time_begin);
my ($RandNum,$RandPercent);
my (@InFile,@OutFile,@ReadNum);
my $HelpInfo = <<USAGE;

 FqRandomSelect_v1.pl
 Auther: zhangdong_xie\@foxmail.com

   This script is used to randomly select reads from raw .fq.gz data;

 -i    For the filepath of .fq.gz ( With equal number of reads );
 -o    For the filepath of selected .fq.gz;
 -n    Reads number to be selected;
 -p    Percent of reads to be selected;
       (-n or -p should be specified only one at a time);
 -h    For help infomation;

USAGE

GetOptions(
	'i=s' => \@InFile,
	'o=s' => \@OutFile,
	'n:i' => \$RandNum,
	'p:f' => \$RandPercent,
	'h!' => \$HelpFlag
) or die $HelpInfo;

if($HelpFlag || !@InFile || !@OutFile || (!$RandNum && !$RandPercent) || ($RandNum && $RandPercent))
{
	die $HelpInfo;
}
else
{
	$time_begin = time;
	if($time_begin)
	{
		my @temp_time = localtime();
		my $localtime_year = $temp_time[5] + 1900;
		my $localtime_month = $temp_time[4] + 1;
		my $localtime_stamp = $localtime_year . "-" . $localtime_month . "-" . $temp_time[3] . "-" . $temp_time[2] . "-" . $temp_time[1] . "-" . $temp_time[0];
		print "[ $localtime_year/$localtime_month/$temp_time[3] $temp_time[2]:$temp_time[1]:$temp_time[0] ] This script begins.\n";
	}
	
	if(@InFile != @OutFile)
	{
		die "The numbers of InFiles and OutFiles are not equal !\n";
	}
	
	for my $i (0 .. $#InFile)
	{
		if($InFile[$i] !~ /.fq.gz$/)
		{
			die "Not standard gz compressed file: $InFile[$i]\n";
		}
	}
	for my $i (0 .. $#OutFile)
	{
		if($OutFile[$i] !~ /.fq.gz$/)
		{
			die "Not standard gz compressed file: $OutFile[$i]\n";
		}
	}
	
	if($RandPercent)
	{
		if($RandPercent <= 0 || $RandPercent > 1)
		{
			die "Percent not correct: $RandPercent.\n";
		}
	}
	
	@ReadNum = ();
	for my $i (0 .. $#InFile)
	{
		my $Return = `zcat $InFile[$i] | wc -l`;
		chomp $Return;
		if($Return % 4)
		{
			die "Not 4 lines seperated: $InFile[$i]\n";
		}
		else
		{
			$Return = int($Return / 4);
		}
		push @ReadNum, $Return;
	}
	my $SharedReadNum = 0;
	for my $i (0 .. $#InFile)
	{
		if($ReadNum[$i] > $SharedReadNum)
		{
			$SharedReadNum = $ReadNum[$i];
		}
	}
	printf "[ %.2fmin ] Reads' numbers are:\t",(time - $time_begin)/60;
	print join("\t",@ReadNum),"\n";
	
	if($RandPercent)
	{
		$RandNum = int($SharedReadNum * $RandPercent);
	}
	elsif($RandNum > $SharedReadNum)
	{
		die "Not enough reads' number.\n";
	}
	printf "[ %.2fmin ] Number to be selected:\t%d\n",(time - $time_begin)/60,$RandNum;
	
	for my $i (0 .. $#OutFile)
	{
		my ($FilePath,$BaseName);
		
		$BaseName = basename $OutFile[$i];
		$FilePath = $OutFile[$i];
		$FilePath =~ s/$BaseName$//;
		`mkdir $FilePath` unless (-d $FilePath);
	}
}


if(@InFile && @OutFile)
{
	my @PickFlag = ();
	for my $i (1 .. $RandNum)
	{
		my $tmp;
		
		do
		{
			$tmp = int(rand($ReadNum[0]));
		}
		while($PickFlag[$tmp]);
		
		$PickFlag[$tmp] = 1;
	}
	
	printf "[ %.2fmin ] Selection begins ...\n",(time - $time_begin)/60;
	for my $i (0 .. $#InFile)
	{
		open(IF,"zcat $InFile[$i] |") or die $!;
		open(OF,"|gzip > $OutFile[$i]") or die $!;
		my $LineNum = 0;
		while(my $IdLine = <IF>)
		{
			my $BaseLine = <IF>;
			my $PlusLine = <IF>;
			my $QualLine = <IF>;
			
			if($PickFlag[$LineNum])
			{
				print OF "$IdLine$BaseLine$PlusLine$QualLine";
			}
			
			$LineNum ++;
		}
		close IF;
		close OF;
		
		printf "[ %.2fmin ] Done: %s.\n",(time - $time_begin)/60,$InFile[$i];
	}
	
	printf "[ %.2fmin ] All done.\n",(time - $time_begin)/60;
}
