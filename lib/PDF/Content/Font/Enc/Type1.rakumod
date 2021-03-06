use PDF::Content::Font::Enc::Glyphic;

#| Implements a Type-1 single byte font encoding scheme.
#| it optimises the encoding to accomodate any subset of
#| <= 255 unique glyphs; by (1) using the standard
#| encoding for the glyph (2) mapping codes that are not
#| used in the encoding scheme, or (3) re-allocating codes
#| that have not been used.
class PDF::Content::Font::Enc::Type1
    does PDF::Content::Font::Enc::Glyphic {
    use PDF::Content::Font::Encodings :mac-encoding, :win-encoding, :sym-encoding, :std-encoding, :zapf-encoding, :zapf-glyphs, :mac-extra-encoding;
    has UInt %!from-unicode;  #| all encoding mappings
    has UInt %.charset{UInt}; #| used characters (useful for subsetting)
    has uint16 @.to-unicode[256];
    has uint8 @!spare-codes;  #| unmapped codes in the encoding scheme
    my subset EncodingScheme of Str where 'mac'|'win'|'sym'|'zapf'|'std'|'mac-extra';
    has EncodingScheme $.enc = 'win';

    submethod TWEAK {
        my array $encoding = %(
            :mac($mac-encoding),   :win($win-encoding),
            :sym($sym-encoding),   :std($std-encoding),
            :mac-extra($mac-extra-encoding),
            :zapf($zapf-encoding),
        ){$!enc};

	self.glyphs = $zapf-glyphs
            if $!enc eq 'zapf';

        @!to-unicode = $encoding.list;
        my uint16 @allocated-codes;
        for 1 .. 255 -> $idx {
            my uint16 $code-point = @!to-unicode[$idx];
            if $code-point {
                %!from-unicode{$code-point} = $idx;
                # CID used in this encoding schema. rellocate as a last resort
                @allocated-codes.unshift: $idx;
            }
            else {
                # spare CID use it first
                @!spare-codes.push($idx)
            }
        }
        # also keep track of codes that are allocated in the encoding scheme, but
        # have not been used in this encoding instance's charset. These can potentially
        # be added to differences to squeeze the most out of our 8-bit encoding scheme.
        @!spare-codes.append: @allocated-codes;
        # map non-breaking space to a regular space
        %!from-unicode{"\c[NO-BREAK SPACE]".ord} //= %!from-unicode{' '.ord};
    }

    method set-encoding($chr-code, $idx) {
        unless %!from-unicode{$chr-code} ~~ $idx {
            %!from-unicode{$chr-code} = $idx;
            @!to-unicode[$idx] = $chr-code;
            %!charset{$chr-code} = $idx;
            $.add-glyph-diff($idx);
        }
    }
    method add-encoding($chr-code, :$idx is copy = %!from-unicode{$chr-code} // 0) {
        if $idx {
            %!charset{$chr-code} = $idx;
        }
        else {
            my $glyph-name = self.lookup-glyph($chr-code);
            if $glyph-name && $glyph-name ne '.notdef' {
                # try to remap the glyph to a spare encoding or other unused glyph
                while @!spare-codes && !$idx {
                    $idx = @!spare-codes.shift;
                    my $old-chr-code = @!to-unicode[$idx];
                    if $old-chr-code && %!charset{$old-chr-code} {
                        # already inuse
                        $idx = 0;
                    }
                    else {
                        # add it to the encoding scheme
                        self.set-encoding($chr-code, $idx);
                   }
                }
            }
        }
        $idx;
    }
    multi method encode(Str $text, :$str! --> Str) {
        self.encode($text).decode: 'latin-1';
    }
    multi method encode(Str $text --> buf8) is default {
        buf8.new: $text.ords.map({%!charset{$_} || self.add-encoding($_) }).grep: {$_};
    }

    multi method decode(Str $encoded, :$str! --> Str) {
        $encoded.ords.map({@!to-unicode[$_]}).grep({$_}).map({.chr}).join;
    }
    multi method decode(Str $encoded --> buf16) {
        buf16.new: $encoded.ords.map({@!to-unicode[$_]}).grep: {$_};
    }

}
