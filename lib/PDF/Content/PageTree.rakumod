use v6;

use PDF::Content::Resourced;

role PDF::Content::PageTree
    does PDF::Content::Resourced {

    use PDF::Content::PageNode;
    use PDF::COS::Dict;
    my subset LeafNode of PDF::Content::PageTree where .Count == + .Kids && .[0] ~~ PDF::Content::PageNode;

    #| add new last page
    method add-page( PDF::Content::PageNode $page? is copy ) {
        my $right-node = self.Kids.tail
            if self.Kids;

	with $page {
	    unless .<Resources>:exists {
		# import resources, if inherited and outside our hierarchy
		with .Resources -> $resources {
                    .<Resources> = $resources.clone
		        unless $resources === self.Resources;
                }
	    }
	}
	else {
	    $_ = PDF::COS::Dict.COERCE: { :Type( :name<Page> ) };
	}

        if $right-node && $right-node.can('add-page') {
            $page = $right-node.add-page( $page );
        }
        else {
            self.Kids.push: $page;
	    $page = self.Kids.tail;
	    $page<Parent> = self.link;
        }

        self<Count>++;
        $page
    }

    #| append page subtree
    method add-pages( PDF::Content::PageNode $pages ) {
	self<Count> += $pages<Count>;
	self<Kids>.push: $pages;
	$pages<Parent> = self;
        $pages;
    }

    #| $.page(0?) - adds a new page
    multi method page(Int $page-num where 0 = 0
	--> PDF::Content::PageNode) {
        self.add-page;
    }

    #| traverse page tree
    multi method page(Int $page-num where { 0 < $_ <= self<Count> }) {
        my Int $page-count = 0;

        for self.Kids.keys {
            my $kid = self.Kids[$_];

            if $kid.can('page') {
                my Int $sub-pages = $kid<Count>;
                my Int $sub-page-num = $page-num - $page-count;

                return $kid.page( $sub-page-num )
                    if 0 < $sub-page-num <= $sub-pages;

                $page-count += $sub-pages
            }
            else {
                $page-count++;
                return $kid
                    if $page-count == $page-num;
            }
        }

        die "unable to locate page: $page-num";
    }

    multi method page(Int $page-num) is default {
	die "no such page: $page-num";
    }

    # build an flattened index of indirect references to pages
    method page-index {
        my @index;
        if self ~~ LeafNode {
            @index = self.Kids.values
        }
        else {
            my $kids := self.Kids;
            for 0 ..^ + $kids {
                given $kids[$_] {
                    when PDF::Content::PageTree { @index.append: .page-index }
                    when PDF::Content::PageNode { @index.push: .ind-ref }
                    default { die "unexpected object in page tree: {.perl}"; }
                }
            }
        }
        @index;
    }

    method pages {
        my @pages;
        my $kids := self.Kids;
        for 0 ..^ + $kids {
            given $kids[$_] {
                when PDF::Content::PageTree { @pages.append: .pages }
                when PDF::Content::PageNode { @pages.push: $_ }
                default { die "unexpected object in page tree: {.perl}"; }
            }
        }
        @pages;
    }

    #| delete page from page tree
    multi method delete-page(Int $page-num where { 0 < $_ <= self<Count>},
	--> PDF::Content::PageNode) {
        my $page-count = 0;

        for self.Kids.keys -> $i {
            my $kid = self.Kids[$i];

            if $kid.can('page') {
                my $sub-pages = $kid<Count>;
                my $sub-page-num = $page-num - $page-count;

                if 0 < $sub-page-num <= $sub-pages {
                    # found in descendant
                    self<Count>--;
                    return $kid.delete-page( $sub-page-num );
                }

                $page-count += $sub-pages
            }
            else {
                $page-count++;
                if $page-count == $page-num {
                    # found at leaf
                    self<Kids>.splice($i, 1);
                    self<Count>--;
                    return $kid
                }
            }
        }

        die "unable to locate page: $page-num";
    }

    method page-count returns UInt { self.Count }

    # allow array indexing of pages $pages[9] :== $.pages.page(10);
    method AT-POS(UInt $pos) is rw {
	# vivify next page
	self.add-page
	   if $pos == self<Count>;
        self.page($pos + 1)
    }

    method cb-finish {
        my Array $kids = self.Kids;
        $kids[$_].cb-finish
            for $kids.keys;
    }

}
