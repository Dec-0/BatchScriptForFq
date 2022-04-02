#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use File::Basename;

my ($HelpFlag,$time_begin);
my ($RecFile,$LogPath);
my (@SP,@Group,@Bed,@Fq1,@Fq2,@RPath,@RFq1,@RFq2,@BaseNum,@ReadLen,@ReadNum,@ExtractReadNum,@Flag);
my $HelpInfo = <<USAGE;

 FqUniform_v2.pl
 Auther: zhangdong_xie\@foxmail.com

  This script was used to uniform the raw depth of samples on diff bed;

 -i    File recording sample name, group id, prefix of fq.gz, bed file;
       (Only support format "SPName\\tGroupId\\tFq1\\tFq2\\tBedFile\\n");
       
 -o    Path where revised fq in;
 -h    For help infomation;

USAGE

GetOptions(
	'i=s' => \$RecFile,
	'o=s' => \$LogPath,
	'h!' => \$HelpFlag
) or die $HelpInfo;

if($HelpFlag || !$RecFile || !$LogPath)
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
		print "[ $localtime_year/$localtime_month/$temp_time[3] $temp_time[2]:$temp_time[1]:$temp_time[0] ] This script (FqUniform_v2) begins.\n";
	}
	
	if($LogPath !~ /\/$/)
	{
		$LogPath .= "/";
	}
}


if($RecFile && $LogPath)
{
	open(REC,"cat $RecFile | grep -v ^# |") or die $!;
	while(my $Line = <REC>)
	{
		chomp $Line;
		my @Cols = split /\t/, $Line;
		push @SP, $Cols[0];
		push @Group, $Cols[1];
		push @Fq1, $Cols[2];
		push @Fq2, $Cols[3];
		push @Bed, $Cols[4];
		
		my @SubCols = split /\//, $Cols[2];
		my $tmpPath = $LogPath . $Cols[1] . "/" . $SubCols[-2];
		push @RPath, $tmpPath;
		my $tmpFile = $tmpPath . "/" . $SubCols[-1];
		push @RFq1, $tmpFile;
		
		@SubCols = split /\//, $Cols[3];
		$tmpFile = $tmpPath . "/" . $SubCols[-1];
		push @RFq2, $tmpFile;
	}
	close REC;
	
	for my $i (0 .. $#Fq1)
	{
		my $tmpNum = `zcat $Fq1[$i] | wc -l`;
		chomp $tmpNum;
		if($tmpNum % 4)
		{
			die "Not standard 4 lines: $Fq1[$i] ($SP[$i])\n";
		}
		
		$tmpNum = int($tmpNum / 4);
		push @ReadNum, $tmpNum;
		
		open(FQ,"zcat $Fq1[$i] |") or die $!;
		<FQ>;
		my $Line = <FQ>;
		close FQ;
		my $tmpLen = length($Line) - 1;
		push @ReadLen, $tmpLen;
		
		printf "[ %.2fmin ] ( %s ) Reads number: %d, ",(time - $time_begin)/60,$SP[$i],$tmpNum;
		
		$tmpNum = $tmpNum * $tmpLen;
		push @BaseNum, $tmpNum;
		
		printf "Reads length: %d.\n",$tmpLen;
	}
	
	&ExtractedNumConfirm();
	
	&FqExtract();
}

sub ExtractedNumConfirm
{
	my (@BedSize,@Depth);
	
	for my $i (0 .. $#Bed)
	{
		my $TotalLen;
		
		$TotalLen = 0;
		open(BE,"< $Bed[$i]") or die $!;
		while(my $Line = <BE>)
		{
			chomp $Line;
			my @Cols = split /\t/, $Line;
			$TotalLen += $Cols[2] - $Cols[1];
		}
		close BE;
		
		push @BedSize, $TotalLen;
	}
	
	my $MinDepth = 100000000;
	for my $i (0 .. $#SP)
	{
		my $tmpNum = $BaseNum[$i] / $BedSize[$i];
		push @Depth, $tmpNum;
		
		if($MinDepth > $tmpNum)
		{
			$MinDepth = $tmpNum;
		}
	}
	printf "[ %.2fmin ] Minimal depth (from single read) for all: %d .\n",(time - $time_begin),$MinDepth;
	
	for my $i (0 .. $#SP)
	{
		my $tmpNum = int(($MinDepth * $BedSize[$i]) / $ReadLen[$i]);
		push @ExtractReadNum, $tmpNum;
		printf "[ %.2fmin ] Reads to be extracted for %s: %d.\n",(time - $time_begin),$SP[$i],$tmpNum;
	}
	
	return 1;
}

sub FqExtract
{
	for my $i (0 .. $#SP)
	{
		`mkdir -p $RPath[$i]` unless(-d $RPath[$i]);
		
		if($ExtractReadNum[$i] > $ReadNum[$i])
		{
			die "Extracted number exceeds original number: $ExtractReadNum[$i] > $ReadNum[$i] ($SP[$i])\n";
		}
		
		@Flag = ();
		my $RNum = $ReadNum[$i] - $ExtractReadNum[$i];
		for my $j (1 .. $RNum)
		{
			my $tmp;
		
			do
			{
				$tmp = int(rand($ReadNum[$i]));
			}
			while($Flag[$tmp]);
			
			$Flag[$tmp] = 1;
		}
		
		&ReadExtract($Fq1[$i],$RFq1[$i]);
		&ReadExtract($Fq2[$i],$RFq2[$i]);
		printf "[ %.2fmin ] Done: %s .\n",(time - $time_begin),$SP[$i];
	}
	
	return 1;
}

sub ReadExtract
{
	my ($OFq,$EFq) = @_;
	
	my $tmpId = 0;
	open(OFQ,"zcat $OFq |") or die $!;
	open(EFQ,"| gzip > $EFq") or die $!;
	while(my $HeadLine = <OFQ>)
	{
		my $BaseLine = <OFQ>;
		my $PlusLine = <OFQ>;
		my $QualLine = <OFQ>;
		
		if(!$Flag[$tmpId])
		{
			print EFQ join("",$HeadLine,$BaseLine,$PlusLine,$QualLine);
		}
		
		$tmpId ++;
	}
	close OFQ;
	close EFQ;
	
	return 1;
}