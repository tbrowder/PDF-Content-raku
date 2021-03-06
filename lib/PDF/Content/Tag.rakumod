use v6;

unit class PDF::Content::Tag;

use PDF::COS;
use PDF::COS::Array;
use PDF::COS::Dict;
use PDF::COS::Stream;

my subset PageLike of Hash where .<Type> ~~ 'Page';
my subset Owner where PageLike|PDF::COS::Stream;
our class Set {...}

has Str $.name is rw;
has Str $.op;
has %.attributes;
has Owner $.owner is required;
has UInt $.start is rw;
has UInt $.end is rw;
has UInt $.mcid is rw; # marked content identifer
has PDF::COS::Stream $.content;
has PDF::Content::Tag $.parent is rw; # hierarchical parent
has Set $.kids handles<AT-POS list grep map tags children elems> .= new;

#| See [PDF 32000 Tables 333 - Standard structure types for grouping elements]
my enum StructureTags is export(:StructureTags,:Tags) (
    :Document<Document>, :Part<Part>, :Article<Art>, :Section<Sect>,
    :Division<Div>, :BlockQuotation<BlockQuote>, :Caption<Caption>,
    :TableOfContents<TOC>, :TableOfContentsItem<TOCI>, :Index<Index>,
    :NonstructuralElement<NonStruct>, :PrivateElement<Private>,
);

#| See [PDF 32000 Tables 334-337 - Block-level structure elements]
my enum ParagraphTags is export(:ParagraphTags,:Tags) (
    :Paragraph<P>, :Header<H>,
    :Header1<H1>,  :Header2<H2>,  :Header3<H3>,
    :Header4<H4>,  :Header5<H5>,  :Header6<H6>,
);
my enum ListElemTags is export(:ListElemTags,:Tags) (
    :List<L>, :ListItem<LI>, :Label<Lbl>, :ListBody<LBody>,
);
my enum TableTags is export(:TableTags,:Tags) (
    :Table<Table>,  :TableRow<TR>,     :TableHeader<TH>,
    :TableData<TD>, :TableBody<TBody>, :TableFooter<TFoot>, 
);

#| See [PDF 32000 Table 338 - Standard structure types for inline-level structure elements]
my enum InlineElemTags is export(:InlineElemTags,:Tags) (
    :Span<Span>, :Quotation<Quote>, :Note<Note>, :Reference<Reference>,
    :BibliographyEntry<BibEntry>, :Code<Code>, :Link<Link>,
    :Annotation<Annot>,
    :Ruby<Ruby>, :RubyPunctutation<RP>, :RubyBaseText<RB>, :RubyText<RT>,
    :Warichu<Warichu>, :WarichuPunctutation<RP>, :WarichuText<RT>,
    :Artifact<Artifact>,
);

my enum IllustrationTags is export(:IllustrationTags,:Tags) (
    :Figure<Figure>, :Formula<Formula>, :Form<Form>
);

constant %TagAliases is export(:TagAliases) = %( StructureTags.enums, ParagraphTags.enums, ListElemTags.enums, TableTags.enums, InlineElemTags.enums, IllustrationTags.enums );
constant TagSet is export(:TagSet) = %TagAliases.values.Set;

multi method add-kid(PDF::Content::Tag $kid) {
    die 'tag already parented by {.gist}' with $kid.parent;
    die "can't add tag to itself"
        if $kid === self;
    $!kids.push: $kid;
    $kid.parent = self;
    $kid;
}

method !attributes-gist {
    given %!attributes {
        my %a = $_;
        %a<MCID> = $_ with self.?mcid;
        %a.pairs.sort.map({ " {.key}=\"{.value}\"" }).join: '';
    }
}

method gist {
    my $attributes = self!attributes-gist();
    $.kids
        ?? [~] flat("<{$.name}$attributes>",
                    $!kids.map(*.gist),
                    "</{$.name}>")
        !! "<{$.name}$attributes/>";
}

method take-descendants {
    take self;
    $!kids.take-descendants;
}

method descendants { gather self.take-descendants }

our class Set {
    my subset Node where PDF::Content::Tag | Str;
    has Node @.tags handles<grep map AT-POS Bool shift push elems>;

    method children { @!tags }
    method take-descendants { @!tags.grep(PDF::Content::Tag).map(*.take-descendants) }
    method descendants { gather self.take-descendants }
    method gist { @!tags.map(*.gist).join }
}
