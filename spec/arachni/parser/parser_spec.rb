require_relative '../../spec_helper'

describe Arachni::Parser do
    before( :all ) do
        @opts = Arachni::Options.instance
        @opts.url = server_url_for( :parser )
        @opts.audit_links = true
        @opts.audit_forms = true
        @opts.audit_cookies = true
        @opts.audit_headers = true
        @opts.cookies = { 'name_from_cookiejar' => 'val_from_cookiejar' }

        @url = @opts.url.to_s + '/?query_var_input=query_var_val'
        @response = Arachni::HTTP.instance.get(
            @url,
            async: false,
            remove_id: true
        ).response
        @parser = Arachni::Parser.new( @opts, @response )
    end

    describe :url do
        it 'should hold the effective URL of the response' do
            @parser.url.should == @url
        end
    end

    describe :opts do
        it 'should hold the provided opts' do
            @parser.opts.should == @opts
        end
    end

    describe :run do
        it 'should return a Page' do
            page = @parser.run

            page.class.should == Arachni::Parser::Page
            page.url.should == @parser.url
            page.code.should == @response.code
            page.method.should == @response.request.method.to_s
            page.query_vars.should == { 'query_var_input' => 'query_var_val' }
            page.body.should == @response.body
            page.response_headers.should == @response.headers_hash
            page.paths.should == @parser.paths

            link = Arachni::Parser::Element::Link.new( @url,
                inputs: @parser.link_vars( @url )
            )
            cookie = Arachni::Parser::Element::Cookie.new( @url, @opts.cookies )

            page.links.should == @parser.links | [link]
            page.forms.should == @parser.forms
            page.cookies.should == @parser.cookies | [cookie]
            page.headers.should == @parser.headers

            h = {}
            page.cookies.each { |c| h.merge!( c.simple ) }
            page.cookiejar.should == h
        end
    end

    describe :text? do
        context 'when the response is text based' do
            it { @parser.text?.should be_true }
        end

        context 'when the response is not text based' do
            before {
                res = Typhoeus::Response.new( effective_url: @url )
                @parser_2 = Arachni::Parser.new( @opts, res )
            }
            it { @parser_2.text?.should be_false }
        end
    end

    describe :doc do
        it 'should return the parsed document' do
            @parser.doc.class == Nokogiri::HTML::Document
        end
    end

    describe :forms do
        it 'should return an array of parsed forms' do
            @parser.forms.size.should == 2

            form = @parser.forms.first
            form.action.should == @opts.url.to_s + '/form'
            form.url.should == @url

            form.auditable.should == {
                "form_input_1" => "form_val_1",
                "form_input_2" => "form_val_2"
            }
            form.method.should == 'post'
            form.raw.should == {
                    "attrs" => {
                    "method" => "post",
                    "action" => form.action,
                      "name" => "my_form"
                },
                 "textarea" => [],
                   "select" => [],
                    "input" => [
                    {
                         "type" => "text",
                         "name" => "form_input_1",
                        "value" => "form_val_1"
                    },
                    {
                         "type" => "text",
                         "name" => "form_input_2",
                        "value" => "form_val_2"
                    },
                    {
                        "type" => "submit"
                    }
                ],
                "auditable" => [
                    {
                         "type" => "text",
                         "name" => "form_input_1",
                        "value" => "form_val_1"
                    },
                    {
                         "type" => "text",
                         "name" => "form_input_2",
                        "value" => "form_val_2"
                    },
                    {
                        "type" => "submit"
                    }
                ]
            }

            form = @parser.forms.last
            form.action.should == @opts.url.to_s + '/form_2'
            form.url.should == @url
            form.auditable.should == { "form_2_input_1" => "form_2_val_1" }
        end
    end

    describe :cookies do
        it 'should return an array of links' do
            @parser.cookies.size.should == 3

            cookies = @parser.cookies

            cookie = cookies.pop
            cookie.action.should == @url
            cookie.auditable.should == { 'cookie_input2' => 'cookie_val2' }
            cookie.method.should == 'cookie'
            cookie.url.should == @url

            cookie = cookies.pop
            cookie.action.should == @url
            cookie.auditable.should == { 'cookie_input' => 'cookie_val' }
            cookie.method.should == 'cookie'
            cookie.url.should == @url

            cookie = cookies.pop
            cookie.action.should == @url
            cookie.auditable.should == { "http_equiv_cookie_name" => "http_equiv_cookie_val" }
            cookie.method.should == 'cookie'
            cookie.url.should == @url
        end
    end

    context 'without base' do
        describe :base do
            it 'should return nil' do
                @parser.base.should == nil
            end
        end

        describe :to_absolute do
            it 'should convert a relative path to absolute' do
                @parser.to_absolute( 'relative/path' ).should == "#{@opts.url}/relative/path"
            end
        end

        describe :links do
            it 'should return an array of links' do
                link = @parser.links.first
                link.action.should == @opts.url.to_s + '/link?link_input=link_val'
                link.auditable.should == { 'link_input' => 'link_val' }
                link.method.should == 'get'
                link.url.should == @url
            end
        end

        describe :paths do
            it 'should return an array of all paths found in the page as absolute URLs' do
                paths = [
                    "link?link_input=link_val",
                    "form",
                    "form_2",
                ].map { |p| @opts.url.to_s + '/' + p }

                (@parser.paths & paths).should == paths
            end
        end
    end

    context 'with base' do
        before {
            @url_with_base = @opts.url.to_s + '/with_base'
            res = Arachni::HTTP.instance.get(
                @url_with_base,
                async: false,
                remove_id: true
            ).response
            @parser_with_base = Arachni::Parser.new( @opts, res )
        }

        describe :base do
            it 'should return the base href attr' do
                @parser_with_base.base.should == "#{@opts.url.to_s}/this_is_the_base/"
            end
        end

        describe :to_absolute do
            it 'should convert a relative path to absolute' do
                @parser_with_base.to_absolute( 'relative/path' ).should == "#{@parser_with_base.base}relative/path"
            end
        end

        describe :links do
            it 'should return an array of links' do
                link = @parser_with_base.links.first
                link.action.should == @parser_with_base.base + 'link_with_base?link_input=link_val'
                link.auditable.should == { 'link_input' => 'link_val' }
                link.method.should == 'get'
                link.url.should == @url_with_base
            end
        end

        describe :paths do
            it 'should return an array of all paths found in the page as absolute URLs' do
                paths = [
                    "",
                    "link_with_base?link_input=link_val",
                ].map { |p| @parser_with_base.base + '' + p }

                (@parser_with_base.paths & paths).should == paths
            end
        end
    end

    describe :headers do
        it 'should return an array of headers' do
            @parser.headers.each {
                |h|
                h.class.should == Arachni::Parser::Element::Header
            }
        end
    end

    describe :link_vars do
        it 'should return a hash of link query inputs' do
            @parser.link_vars( @url ).should == { "query_var_input" => "query_var_val" }
        end
    end

    describe :extract_domain do
        it 'should return the domain name from a URI object' do
            @parser.extract_domain( URI( @url ) ).should == 'localhost'
        end
    end

    describe :too_deep? do
        before { @parser.opts.depth_limit = 3 }

        context 'when the path is above the threshold' do
            it 'should return true' do
                @parser.too_deep?( @opts.url.to_s + '/test/test/test//test/test' )
                .should be_true

                @parser.skip?( @opts.url.to_s + '/test/test/test//test/test' )
                .should be_true
            end
        end
        context 'when the path is bellow the threshold' do
            it 'should return false' do
                @parser.too_deep?( @opts.url.to_s + '/test/test/test' )
                .should be_false

                @parser.skip?( @opts.url.to_s + '/test/test/test' )
                .should be_false
            end
        end
    end

    describe :in_domain? do
        before { @parser.url = 'http://bar.com' }

        context 'when follow subdomains is disabled' do
            before { @parser.opts.follow_subdomains = false }

            context 'with a URL with a different domain' do
                it 'should return false' do
                    @parser.in_domain?( 'http://google.com' ).should be_false
                    @parser.skip?( 'http://google.com' ).should be_true
                end
            end

            context 'with a URL with the same domain' do
                it 'should return true' do
                    @parser.in_domain?( 'http://bar.com/test/' ).should be_true
                    @parser.skip?( 'http://bar.com/test/' ).should be_false
                end
            end


            context 'with a URL with a different subdomain' do
                it 'should return false' do
                    @parser.in_domain?( 'http://test.bar.com/test' ).should be_false
                    @parser.skip?( 'http://test.bar.com/test' ).should be_true
                end
            end
        end

        context 'when follow subdomains is disabled' do
            before { @parser.opts.follow_subdomains = true }

            context 'with a URL with a different domain' do
                it 'should return false' do
                    @parser.in_domain?( 'http://google.com' ).should be_false
                    @parser.skip?( 'http://google.com' ).should be_true
                end
            end

            context 'with a URL with the same domain' do
                it 'should return true' do
                    @parser.in_domain?( 'http://bar.com/test/' ).should be_true
                    @parser.skip?( 'http://bar.com/test/' ).should be_false
                end
            end


            context 'with a URL with a different subdomain' do
                it 'should return true' do
                    @parser.in_domain?( 'http://test.bar.com/test' ).should be_true
                    @parser.skip?( 'http://test.bar.com/test' ).should be_false
                end
            end
        end
    end

    describe :exclude? do
        before { @parser.opts.exclude << /skip_me/ }

        context 'when a path matches an exclude rule' do
            it 'should return true' do
                @parser.exclude?( 'skip_me' ).should be_true
                @parser.skip?( 'http://bar.com/skip_me' ).should be_true
            end
        end

        context 'when a path does not match an exclude rule' do
            it 'should return false' do
                @parser.exclude?( 'not_me' ).should be_false
                @parser.skip?( 'http://bar.com/not_me' ).should be_false
            end
        end
    end

    describe :include? do
        before { @parser.opts.include << /include_me/ }

        context 'when a path matches an include rule' do
            it 'should return true' do
                @parser.include?( 'include_me' ).should be_true
                @parser.skip?( 'http://bar.com/include_me' ).should be_false
            end
        end

        context 'when a path does not match an include rule' do
            it 'should return false' do
                @parser.include?( 'not_me' ).should be_false
                @parser.skip?( 'http://bar.com/not_me' ).should be_true
            end
        end
    end

end