use v6;
use Test;
plan 8;
use lib 't';
use PDF::Grammar::Test :is-json-equiv;
use PDF::Content::Text::Box;
use PDF::Content::Font::CoreFont;
use PDF::Content::Color :color, :ColorName;
use PDFTiny;

my \nbsp = "\c[NO-BREAK SPACE]";
my @chunks =  PDF::Content::Text::Box.comb: "z80 a-b. -3   {nbsp}A{nbsp}bc{nbsp} 42";
is-deeply @chunks, ["z80", " ", "a-", "b.", " ", "-", "3", "   ", "{nbsp}A{nbsp}bc{nbsp}", " ", "42"], 'text-box comb';

my PDF::Content::Font::CoreFont $font .= load-font( :family<helvetica>, :weight<bold> );
my $font-size = 16;
my $text = "Hello.  Ting, ting-ting. Attention! … ATTENTION! ";
my PDFTiny $pdf .= new;
my PDF::Content::Text::Box $text-box .= new( :$text, :$font, :$font-size );
is-approx $text-box.content-width, 365.328, '$.content-width';
is-approx $text-box.content-height, 17.6, '$.content-height';
my $gfx = $pdf.add-page.gfx;
$gfx.Save;
$gfx.BeginText;
$gfx.text-position = [100, 350];
$gfx.FillColor = color Blue;
is-deeply $gfx.text-position, (100.0, 350.0), 'text position';
$gfx.say( $text-box );
is-deeply $gfx.text-position, (100.0, 350 - 17.6), 'text position';
$text-box .= new( :$text, :$font, :$font-size, :squish );
is-approx $text-box.content-width, 360.88, '$.content-width (squished)';
is-approx $text-box.content-height, 17.6, '$.content-height (squished)';
$text-box.TextRise = $text-box.baseline-shift('bottom');
$gfx.print( $text-box, :!preserve );
$gfx.EndText;
$gfx.Restore;

is-json-equiv [ $gfx.ops ], [
    :q[],
      :BT[],
        :Tm[ :real(1),   :real(0),
             :real(0),   :real(1),
             :real(100), :real(350), ],
        :rg[ :real(0), :real(0), :real(1) ],
        :Tf[:name<F1>,   :real(16)],
        :Tj[ :literal("Hello.  Ting, ting-ting. Attention! \x[85] ATTENTION!")],
        :TL[:real(17.6)],
        'T*' => [],
        :Ts[ :real(3.648) ],
        :Tj[ :literal("Hello. Ting, ting-ting. Attention! \x[85] ATTENTION!")],
      :ET[],
    :Q[],
    ], 'simple text box';

# ensure consistant document ID generation
srand(123456);

$pdf.save-as: "t/text-box.pdf";
