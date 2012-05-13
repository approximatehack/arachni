require_relative '../spec_helper'

describe Arachni::ComponentManager do
    before( :all ) do
        @opts = Arachni::Options.instance
        @lib = @opts.dir['plugins']
        @namespace = Arachni::Plugins
        @components = Arachni::ComponentManager.new( @lib, @namespace )
    end

    after( :each ) { @components.clear }

    describe :lib do
        it 'should return the component library' do
            @components.lib.should == @lib
        end
    end

    describe :namespace do
        it 'should return the namespace under which all components are defined' do
            @components.namespace.should == @namespace
        end
    end

    describe :available do
        it 'should return all available components' do
            @components.available.sort.should == %w(wait bad distributable loop default with_options).sort
        end
    end

    describe :load do
        context 'when passed a string' do
            it 'should load components by name' do
                @components.load( 'wait' )
                @components.loaded.should == %w(wait)
            end
        end
        context 'when passed an array' do
            it 'should load the component by name' do
                @components.load( %w(bad distributable) )
                @components.loaded.sort.should == %w(bad distributable).sort
            end
        end

        context 'when passed a wildcard' do
            context 'alone' do
                it 'should load all components' do
                    @components.load( '*' )
                    @components.loaded.sort.should == @components.available.sort
                end
            end

            context 'with a category name' do
                it 'should load all of its components' do
                    @components.load( 'plugins/*' )
                    @components.loaded.sort.should == @components.available.sort
                end
            end

        end

        context 'when passed an exclusion filter' do
            context 'alone' do
                it 'should not load anything' do
                    @components.load( '-' )
                    @components.loaded.sort.should be_empty
                end
            end
            context 'with a name' do
                it 'should not load that component' do
                    @components.load( %w(* -wait) )
                    loaded = @components.available
                    loaded.delete( 'wait' )
                    @components.loaded.sort.should == loaded.sort
                end
            end
            context 'with a partial name and a wildcard' do
                it 'should not load matching components' do
                    @components.load( %w(* -wai* -dist*) )
                    loaded = @components.available
                    loaded.delete( 'wait' )
                    loaded.delete( 'distributable' )
                    @components.loaded.sort.should == loaded.sort
                end
            end
        end
    end

    describe :parse do
        context 'when passed a string' do
            it 'should return components by name' do
                @components.parse( 'wait' ).should == %w(wait)
            end
        end
        context 'when passed an array' do
            it 'should load the component by name' do
                @components.parse( %w(bad distributable) ).sort.should ==
                    %w(bad distributable).sort
            end
        end

        context 'when passed a wildcard' do
            context 'alone' do
                it 'should return all components' do
                    @components.parse( '*' ).sort.should == @components.available.sort
                end
            end

            context 'with a category name' do
                it 'should return all of its components' do
                    @components.parse( 'plugins/*' ).sort.should == @components.available.sort
                end
            end

        end

        context 'when passed an exclusion filter' do
            context 'alone' do
                it 'should not return anything' do
                    @components.parse( '-' ).sort.should be_empty
                end
            end
            context 'with a name' do
                it 'should not return that component' do
                    @components.parse( %w(* -wait) )
                    loaded = @components.available
                    loaded.delete( 'wait' )
                    loaded.sort.should == loaded.sort
                end
            end
            context 'with a partial name and a wildcard' do
                it 'should not return matching components' do
                    parsed = @components.parse( %w(* -wai* -dist*) )
                    loaded = @components.available
                    loaded.delete( 'wait' )
                    loaded.delete( 'distributable' )
                    parsed.sort.should == loaded.sort
                end
            end
        end
    end

    describe :prep_opts do
        it 'should prepare options for passing to the component' do
            c = 'with_options'

            @components.load( c )
            @components.prep_opts( c, @components[c],
                { 'req_opt' => 'my value'}
            ).should == {
                    "req_opt" => "my value",
                    "opt_opt" => nil,
                "default_opt" => "value"
            }

            opts = {
                'req_opt' => 'req_opt value',
                'opt_opt' => 'opt_opt value',
                "default_opt" => "default_opt value"
            }
            @components.prep_opts( c, @components[c], opts ).should == opts
        end

        context 'when invalid options' do
            it 'should raise an exception' do
                raised = false
                begin
                    c = 'with_options'
                    @components.load( c )
                    @components.prep_opts( c, @components[c], {} )
                rescue Arachni::ComponentManager::InvalidOptions
                    raised = true
                end

                raised.should be_true
            end
        end
    end

    describe :[] do
        it 'should load and return a component' do
            @components.loaded.should be_empty
            @components['wait'].name.should == 'Arachni::Plugins::Wait'
            @components.loaded.should == %w(wait)
        end
    end

    describe :delete do
        it 'should remove and unload a component' do
            @components.loaded.should be_empty

            @components.load( 'wait' )
            klass = @components['wait']

            sym = klass.name.split( ':' ).last.to_sym
            @components.namespace.constants.include?( sym ).should be_true
            @components.loaded.should be_any

            @components.delete( 'wait' )
            @components.loaded.should be_empty

            sym = klass.name.split( ':' ).last.to_sym
            @components.namespace.constants.include?( sym ).should be_false
        end
    end

    describe :available do
        it 'should return all available components' do
            @components.available.sort.should == %w(wait bad with_options distributable loop default).sort
        end
    end

    describe :loaded do
        it 'should return all loaded components' do
            @components.load( '*' )
            @components.loaded.sort.should == %w(wait bad with_options distributable loop default).sort
        end
    end

    describe :name_to_path do
        it 'should return a component\'s path from its name' do
            path = @components.name_to_path( 'wait' )
            File.exists?( path ).should be_true
            File.basename( path ).should == 'wait.rb'
        end
    end

    describe :path_to_name do
        it 'should return a component\'s path from its name' do
            path = @components.name_to_path( 'wait' )
            @components.path_to_name( path ).should == 'wait'
        end
    end

    describe :paths do
        it 'should return all component paths' do
            paths = @components.paths
            paths.each { |p| File.exists?( p ).should be_true }
            paths.size.should == @components.available.size
        end
    end

    describe :clear do
        it 'should unload all components' do
            @components.loaded.should be_empty
            @components.load( '*' )
            @components.loaded.sort.should == @components.available.sort

            symbols = @components.values.map do |klass|
                sym = klass.name.split( ':' ).last.to_sym
                @components.namespace.constants.include?( sym ).should be_true
                sym
            end

            @components.clear
            symbols.each do |sym|
                @components.namespace.constants.include?( sym ).should be_false
            end
            @components.loaded.should be_empty
        end
    end
end