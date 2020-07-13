#!/usr/bin/perl -w

use strict;
use utf8;
use open ':std', ':utf8';

sub test_word;

# From https://www.mdbg.net/chinese/dictionary?page=cc-cedict
my $cedict_default = 'cedict_1_0_ts_utf-8_mdbg.txt';
my $words_default = '/usr/share/dict/words';

sub usage {
  print <<EOF;
Print English words that can be read as (toneless) pinyin syllables, along with
the Chinese words they correspond to.

usage: $0 [-n] [CEDICT [WORDS]]

  -n
    Print words that can be split into pinyin syllables but which have no
    Chinese homonym.

  CEDICT
    Location of the CEDICT dictionary to use; see
    https://www.mdbg.net/chinese/dictionary?page=cc-cedict.

    Defaults to $cedict_default.

  WORDS
    Location of the English dictionary to use.

    Defaults to $words_default.
EOF
  exit 1;
}

my $nonsense = 0;

my @file_args = grep { !/^-./ } @ARGV;
usage() if @file_args > 2;
for (grep { /^-./ } @ARGV) {
  usage() unless $_ eq '-n';
  $nonsense = 1;
}

my $cedict_file = $file_args[0] || $cedict_default;
my $words_file = $file_args[1] || $words_default;

# From http://research.chtsai.org/papers/pinyin-xref.html, plus lüe and nüe,
# since they appear in CEDICT.
my @syllables = qw(
a ai an ang ao ba bai ban bang bao bei ben beng bi bian biao bie bin bing bo bu
ca cai can cang cao ce cen ceng cha chai chan chang chao che chen cheng chi
chong chou chu chua chuai chuan chuang chui chun chuo ci cong cou cu cuan cui
cun cuo da dai dan dang dao de dei den deng di dian diao die ding diu dong dou
du duan dui dun duo e ei en eng er fa fan fang fei fen feng fo fou fu ga gai gan
gang gao ge gei gen geng gong gou gu gua guai guan guang gui gun guo ha hai han
hang hao he hei hen heng hong hou hu hua huai huan huang hui hun huo ji jia jian
jiang jiao jie jin jing jiong jiu ju juan jue jun ka kai kan kang kao ke kei ken
keng kong kou ku kua kuai kuan kuang kui kun kuo la lai lan lang lao le lei leng
li lia lian liang liao lie lin ling liu long lou lu lü luan lue lüe lun luo ma
mai man mang mao me mei men meng mi mian miao mie min ming miu mo mou mu na nai
nan nang nao ne nei nen neng ni nian niang niao nie nin ning niu nong nou nu nü
nüe nuan nue nuo o ou pa pai pan pang pao pei pen peng pi pian piao pie pin ping
po pou pu qi qia qian qiang qiao qie qin qing qiong qiu qu quan que qun ran rang
rao re ren reng ri rong rou ru ruan rui run ruo sa sai san sang sao se sei sen
seng sha shai shan shang shao she shei shen sheng shi shou shu shua shuai shuan
shuang shui shun shuo si song sou su suan sui sun suo ta tai tan tang tao te
teng ti tian tiao tie ting tong tou tu tuan tui tun tuo wa wai wan wang wei wen
weng wo wu xi xia xian xiang xiao xie xin xing xiong xiu xu xuan xue xun ya yan
yang yai yao ye yi yin ying yo yong you yu yuan yue yun za zai zan zang zao ze
zei zen zeng zha zhai zhan zhang zhao zhe zhei zhen zheng zhi zhong zhou zhu
zhua zhuai zhuan zhuang zhui zhun zhuo zi zong zou zu zuan zui zun zuo
);
my %syllables = ();
my $max_syllable_len = 0;
for (@syllables) {
  $syllables{$_} = 1;
  $max_syllable_len = length($_) if length($_) > $max_syllable_len;
}

# Which vowel to place a tone mark on when there's more than one
my %vowels = (
  ai => 'a',
  ao => 'a',
  ei => 'e',
  ia => 'a',
  iao => 'a',
  ie => 'e',
  io => 'o',
  iu => 'u',
  ou => 'o',
  ua => 'a',
  uai => 'a',
  ue => 'e',
  ui => 'i',
  uo => 'o',
  üe => 'e',
);

my %tones = (
  a1 => 'ā', a2 => 'á', a3 => 'ǎ', a4 => 'à',
  e1 => 'ē', e2 => 'é', e3 => 'ě', e4 => 'è',
  i1 => 'ī', i2 => 'í', i3 => 'ǐ', i4 => 'ì',
  o1 => 'ō', o2 => 'ó', o3 => 'ǒ', o4 => 'ò',
  u1 => 'ū', u2 => 'ú', u3 => 'ǔ', u4 => 'ù',
  ü1 => 'ǖ', ü2 => 'ǘ', ü3 => 'ǚ', ü4 => 'ǜ',
);

sub intone_one {
  my $vowel = shift;
  my $tone = shift;
  return $tone == 5 ? $vowel : $tones{$vowel . $tone};
}

sub intone {
  my $syllable = shift;

  $syllable =~ s/(\d)//;
  my $tone = $1;

  if ($tone != 5) {
    my $vowels = $syllable;
    $vowels =~ s/[^aeiouü]//g;

    my $to_intone = length($vowels) == 1 ? $vowels : $vowels{$vowels};
    my $intoned = intone_one($to_intone, $tone);
    $syllable =~ s/$to_intone/$intoned/;
  }

  return $syllable;
}

my %words = ();
open CEDICT, $cedict_file;
while (<CEDICT>) {
  chomp;
  my $line = $_;
  next if /^#/;
  /^(\S+) \S+ \[(.*?)\] (\/.*)$/ or die;

  my $chinese = $1;
  my $pinyin = $2;
  my $def = $3;

  next unless $pinyin =~ /^[A-Za-z:]+\d( [A-Za-z:]+\d)*$/;
  next if $pinyin =~ /^m\d/;
  $pinyin = lc $pinyin;
  $pinyin =~ s/u:/ü/g;

  # Skip entries where the number of characters doesn't match the number of syllables.
  next if scalar(split('', $chinese)) != scalar(split(/ /, $pinyin));

  my $toneless = $pinyin;
  $toneless =~ s/\d//g;
  $pinyin = join(' ', map { intone($_) } split(/ /, $pinyin));

  # Drop some uninteresting parts of definitions.
  $def =~ s{/(CL:|see |same as )[^/]*?/}{/}g;
  $def =~ s{/[^/]*(pr\.|variant of|Kangxi radical \d)[^/]*/}{/}g;
  $def =~ s{/\([^/]*\)/}{/}g;
  $def =~ s/\|\p{Han}+//g;
  $def =~ s/(\p{Han})\[[A-Za-z0-9 ]+\]/$1/g;

  next if $def eq '/';

  $words{$toneless} = [] unless exists $words{$toneless};
  push @{$words{$toneless}}, { pinyin => $pinyin, chinese => $chinese, def => $def };
}
close CEDICT;

open WORDS, $words_file;
while (<WORDS>) {
  chomp;
  test_word($_, [], 0);
}
close WORDS;

sub test_word {
  my $word = shift;
  my $indexes = shift;
  my $next_index = shift;

  if ($next_index == length($word)) {
    my $pinyin = '';
    for (my $i = 0; $i < @$indexes - 1; $i++) {
      $pinyin .= substr($word, @$indexes[$i], @$indexes[$i + 1] - @$indexes[$i]) . ' ';
    }
    $pinyin .= substr($word, @$indexes[-1]);
    if (!$nonsense && exists $words{$pinyin}) {
      print "$word [$pinyin]\n";
      if (exists $words{$pinyin}) {
	for (@{$words{$pinyin}}) {
	  print "  $_->{chinese} [$_->{pinyin}] $_->{def}\n";
	}
      }
    } elsif ($nonsense && !exists $words{$pinyin}) {
      print "$word [$pinyin]\n";
    }
    return;
  }

  for (my $len = 1; $len <= length($word) - $next_index && $len < $max_syllable_len; ++$len) {
    if (exists $syllables{substr($word, $next_index, $len)}) {
      test_word($word, [@$indexes, $next_index], $next_index + $len);
    }
  }
}
