# frozen_string_literal: true

module TRuby
  # TypeEnv - 타입 환경 (스코프 체인)
  # TypeScript의 Checker에서 심볼 타입을 추적하는 방식을 참고
  class TypeEnv
    attr_reader :parent, :bindings, :instance_vars

    def initialize(parent = nil)
      @parent = parent
      @bindings = {}      # 지역 변수 { name => type }
      @instance_vars = {} # 인스턴스 변수 { name => type }
      @class_vars = {}    # 클래스 변수 { name => type }
    end

    # 지역 변수 타입 정의
    # @param name [String] 변수 이름
    # @param type [IR::TypeNode, String] 타입
    def define(name, type)
      @bindings[name] = type
    end

    # 변수 타입 조회 (스코프 체인 탐색)
    # @param name [String] 변수 이름
    # @return [IR::TypeNode, String, nil] 타입 또는 nil
    def lookup(name)
      # 인스턴스 변수
      if name.start_with?("@") && !name.start_with?("@@")
        return lookup_instance_var(name)
      end

      # 클래스 변수
      if name.start_with?("@@")
        return lookup_class_var(name)
      end

      # 지역 변수 또는 메서드 파라미터
      return @bindings[name] if @bindings.key?(name)

      # 부모 스코프에서 검색
      @parent&.lookup(name)
    end

    # 인스턴스 변수 타입 정의
    # @param name [String] 변수 이름 (@포함)
    # @param type [IR::TypeNode, String] 타입
    def define_instance_var(name, type)
      # @ 접두사 정규화
      normalized = name.start_with?("@") ? name : "@#{name}"
      @instance_vars[normalized] = type
    end

    # 인스턴스 변수 타입 조회
    # @param name [String] 변수 이름 (@포함)
    # @return [IR::TypeNode, String, nil] 타입 또는 nil
    def lookup_instance_var(name)
      normalized = name.start_with?("@") ? name : "@#{name}"
      return @instance_vars[normalized] if @instance_vars.key?(normalized)

      @parent&.lookup_instance_var(normalized)
    end

    # 클래스 변수 타입 정의
    # @param name [String] 변수 이름 (@@포함)
    # @param type [IR::TypeNode, String] 타입
    def define_class_var(name, type)
      normalized = name.start_with?("@@") ? name : "@@#{name}"
      @class_vars[normalized] = type
    end

    # 클래스 변수 타입 조회
    # @param name [String] 변수 이름 (@@포함)
    # @return [IR::TypeNode, String, nil] 타입 또는 nil
    def lookup_class_var(name)
      normalized = name.start_with?("@@") ? name : "@@#{name}"
      return @class_vars[normalized] if @class_vars.key?(normalized)

      @parent&.lookup_class_var(normalized)
    end

    # 자식 스코프 생성 (블록, 람다 등)
    # @return [TypeEnv] 새 자식 스코프
    def child_scope
      TypeEnv.new(self)
    end

    # 현재 스코프에서 정의된 모든 변수 이름
    # @return [Array<String>] 변수 이름 배열
    def local_names
      @bindings.keys
    end

    # 현재 스코프에서 정의된 모든 인스턴스 변수 이름
    # @return [Array<String>] 인스턴스 변수 이름 배열
    def instance_var_names
      @instance_vars.keys
    end

    # 변수가 현재 스코프에 정의되어 있는지 확인
    # @param name [String] 변수 이름
    # @return [Boolean]
    def defined_locally?(name)
      @bindings.key?(name)
    end

    # 스코프 깊이 (디버깅용)
    # @return [Integer] 스코프 깊이
    def depth
      @parent ? @parent.depth + 1 : 0
    end

    # 스코프 체인에서 모든 변수 수집
    # @return [Hash] 모든 변수의 { name => type }
    def all_bindings
      parent_bindings = @parent ? @parent.all_bindings : {}
      parent_bindings.merge(@bindings)
    end

    # 디버그 출력
    def to_s
      parts = ["TypeEnv(depth=#{depth})"]
      parts << "  locals: #{@bindings.keys.join(", ")}" if @bindings.any?
      parts << "  ivars: #{@instance_vars.keys.join(", ")}" if @instance_vars.any?
      parts.join("\n")
    end
  end
end
