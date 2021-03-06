role PDF::Content::Font::Enc::Glyphic {
    use Font::AFM;
    has Hash $.glyphs is rw = %Font::AFM::Glyphs;
    use PDF::COS;
    use PDF::COS::Name;
    my subset NameOrUInt where PDF::COS::Name|UInt;
    has NameOrUInt @!differences;
    has uint8 @!diff-cids;
    has Bool  $!diff-cids-updated = False;

    method lookup-glyph(UInt $chr-code) {
        $!glyphs{$chr-code.chr}
    }

    method glyph-map {
        %( $!glyphs.invert );
    }

    method add-glyph-diff(UInt $idx) {
        @!diff-cids.push: $idx;
        $!diff-cids-updated = True;
    }

    method differences is rw {
        Proxy.new(
            STORE => -> $, @diffs {
                my %glyph-map := self.glyph-map;
                my uint32 $idx = 0;
                @!differences = @diffs.map: {
                    when UInt { $idx  = $_ }
                    when Str {
                        self.set-encoding(.ord, $idx)
                            with %glyph-map{$_};
                        $idx++;
                        PDF::COS::Name.COERCE($_);
                    }
                    default { die "bad difference entry: .perl" }
                }
                $!diff-cids-updated = False;
            },
            FETCH => {
                if $!diff-cids-updated {
                    @!differences = ();
                    my int $cur-idx = -2;
                    for @!diff-cids.list.sort {
                        unless $_ == ++$cur-idx {
                            @!differences.push: $_;
                            $cur-idx = $_;
                        }
                        my PDF::COS::Name $glyph-name .= COERCE(
                            self.lookup-glyph( @.to-unicode[$_] ) // '.notdef',
                        );
                        @!differences.push: $glyph-name;
                    }
                    $!diff-cids-updated = False;
                }
                @!differences;
            },
        )
    }
}
