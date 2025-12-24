# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "fileutils"
require "rbs"

RSpec.describe "Type Inference E2E" do
  let(:tmpdir) { Dir.mktmpdir("trb_type_inference_e2e") }

  before do
    @original_dir = Dir.pwd
  end

  after do
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(tmpdir)
  end

  def create_config_file(yaml_content)
    config_path = File.join(tmpdir, "trbconfig.yml")
    File.write(config_path, yaml_content)
    config_path
  end

  def create_trb_file(relative_path, content)
    full_path = File.join(tmpdir, relative_path)
    FileUtils.mkdir_p(File.dirname(full_path))
    File.write(full_path, content)
    full_path
  end

  def compile_and_get_rbs(trb_path, rbs_dir: "sig")
    config = TRuby::Config.new
    compiler = TRuby::Compiler.new(config)
    compiler.compile(trb_path)

    relative_path = trb_path.sub("#{tmpdir}/src/", "")
    rbs_path = File.join(tmpdir, rbs_dir, relative_path.sub(".trb", ".rbs"))
    File.read(rbs_path) if File.exist?(rbs_path)
  end

  def expect_valid_rbs(rbs_content)
    expect(rbs_content).not_to be_nil
    expect(rbs_content.strip).not_to be_empty

    begin
      RBS::Parser.parse_signature(rbs_content)
    rescue RBS::ParsingError => e
      raise "Generated RBS is invalid:\n#{rbs_content}\n\nParsing error: #{e.message}"
    end

    rbs_content
  end

  describe "literal type inference" do
    it "infers String from string literal" do
      Dir.chdir(tmpdir) do
        create_config_file(<<~YAML)
          source:
            include:
              - src
          output:
            ruby_dir: build
            rbs_dir: sig
          compiler:
            generate_rbs: true
        YAML

        create_trb_file("src/literals.trb", <<~TRB)
          class Literals
            def string_method
              "hello world"
            end
          end
        TRB

        rbs_content = compile_and_get_rbs(File.join(tmpdir, "src/literals.trb"))
        expect_valid_rbs(rbs_content)

        expect(rbs_content).to include("def string_method: () -> String")
      end
    end

    it "infers Integer from integer literal" do
      Dir.chdir(tmpdir) do
        create_config_file(<<~YAML)
          source:
            include:
              - src
          output:
            ruby_dir: build
            rbs_dir: sig
          compiler:
            generate_rbs: true
        YAML

        create_trb_file("src/int.trb", <<~TRB)
          class IntTest
            def number
              42
            end
          end
        TRB

        rbs_content = compile_and_get_rbs(File.join(tmpdir, "src/int.trb"))
        expect_valid_rbs(rbs_content)

        expect(rbs_content).to include("def number: () -> Integer")
      end
    end

    it "infers bool from boolean literal" do
      Dir.chdir(tmpdir) do
        create_config_file(<<~YAML)
          source:
            include:
              - src
          output:
            ruby_dir: build
            rbs_dir: sig
          compiler:
            generate_rbs: true
        YAML

        create_trb_file("src/bool.trb", <<~TRB)
          class BoolTest
            def flag
              true
            end
          end
        TRB

        rbs_content = compile_and_get_rbs(File.join(tmpdir, "src/bool.trb"))
        expect_valid_rbs(rbs_content)

        expect(rbs_content).to include("def flag: () -> bool")
      end
    end

    it "infers Symbol from symbol literal" do
      Dir.chdir(tmpdir) do
        create_config_file(<<~YAML)
          source:
            include:
              - src
          output:
            ruby_dir: build
            rbs_dir: sig
          compiler:
            generate_rbs: true
        YAML

        create_trb_file("src/sym.trb", <<~TRB)
          class SymTest
            def status
              :ok
            end
          end
        TRB

        rbs_content = compile_and_get_rbs(File.join(tmpdir, "src/sym.trb"))
        expect_valid_rbs(rbs_content)

        expect(rbs_content).to include("def status: () -> Symbol")
      end
    end
  end

  describe "variable type inference" do
    it "infers type from instance variable assigned in initialize" do
      Dir.chdir(tmpdir) do
        create_config_file(<<~YAML)
          source:
            include:
              - src
          output:
            ruby_dir: build
            rbs_dir: sig
          compiler:
            generate_rbs: true
        YAML

        create_trb_file("src/ivar.trb", <<~TRB)
          class IvarTest
            def initialize(name: String): void
              @name = name
            end

            def get_name
              @name
            end
          end
        TRB

        rbs_content = compile_and_get_rbs(File.join(tmpdir, "src/ivar.trb"))
        expect_valid_rbs(rbs_content)

        # @name is String (from initialize parameter)
        # get_name returns @name, so it should be String
        expect(rbs_content).to include("def get_name: () -> String")
      end
    end
  end

  describe "explicit return type takes precedence" do
    it "uses explicit type over inferred type" do
      Dir.chdir(tmpdir) do
        create_config_file(<<~YAML)
          source:
            include:
              - src
          output:
            ruby_dir: build
            rbs_dir: sig
          compiler:
            generate_rbs: true
        YAML

        create_trb_file("src/explicit.trb", <<~TRB)
          class ExplicitTest
            def message(): String
              "hello"
            end
          end
        TRB

        rbs_content = compile_and_get_rbs(File.join(tmpdir, "src/explicit.trb"))
        expect_valid_rbs(rbs_content)

        # Explicit return type should be used
        expect(rbs_content).to include("def message: () -> String")
      end
    end
  end

  describe "method call type inference" do
    it "infers type from builtin method return" do
      Dir.chdir(tmpdir) do
        create_config_file(<<~YAML)
          source:
            include:
              - src
          output:
            ruby_dir: build
            rbs_dir: sig
          compiler:
            generate_rbs: true
        YAML

        create_trb_file("src/method_call.trb", <<~TRB)
          class MethodCallTest
            def shout(text: String)
              text.upcase
            end
          end
        TRB

        rbs_content = compile_and_get_rbs(File.join(tmpdir, "src/method_call.trb"))
        expect_valid_rbs(rbs_content)

        # String#upcase returns String
        expect(rbs_content).to include("def shout: (text: String) -> String")
      end
    end
  end

  describe "array literal type inference" do
    it "infers Array type with element type" do
      Dir.chdir(tmpdir) do
        create_config_file(<<~YAML)
          source:
            include:
              - src
          output:
            ruby_dir: build
            rbs_dir: sig
          compiler:
            generate_rbs: true
        YAML

        create_trb_file("src/array.trb", <<~TRB)
          class ArrayTest
            def numbers
              [1, 2, 3]
            end
          end
        TRB

        rbs_content = compile_and_get_rbs(File.join(tmpdir, "src/array.trb"))
        expect_valid_rbs(rbs_content)

        expect(rbs_content).to include("def numbers: () -> Array[Integer]")
      end
    end
  end

  describe "initialize method inference" do
    it "infers void for initialize without explicit return type" do
      Dir.chdir(tmpdir) do
        create_config_file(<<~YAML)
          source:
            include:
              - src
          output:
            ruby_dir: build
            rbs_dir: sig
          compiler:
            generate_rbs: true
        YAML

        create_trb_file("src/init.trb", <<~TRB)
          class Person
            def initialize(name: String)
              @name = name
            end

            def greet
              "Hello"
            end
          end
        TRB

        rbs_content = compile_and_get_rbs(File.join(tmpdir, "src/init.trb"))
        expect_valid_rbs(rbs_content)

        # initialize should return void (Ruby convention for constructors)
        # The actual instance creation is done by Class.new, not initialize
        expect(rbs_content).to include("def initialize: (name: String) -> void")
      end
    end

    it "respects explicit void return type on initialize" do
      Dir.chdir(tmpdir) do
        create_config_file(<<~YAML)
          source:
            include:
              - src
          output:
            ruby_dir: build
            rbs_dir: sig
          compiler:
            generate_rbs: true
        YAML

        create_trb_file("src/init_explicit.trb", <<~TRB)
          class User
            def initialize(id: Integer): void
              @id = id
            end
          end
        TRB

        rbs_content = compile_and_get_rbs(File.join(tmpdir, "src/init_explicit.trb"))
        expect_valid_rbs(rbs_content)

        expect(rbs_content).to include("def initialize: (id: Integer) -> void")
      end
    end
  end
end
