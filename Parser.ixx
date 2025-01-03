module;
#include <cstdint>
export module Parser;

import WinRT;
import Environment;

namespace Parser
{
    export enum class ResultType : uint8_t
    {
        Invalid,
        Assignment,
        Expression
    };

    export std::tuple<std::string, winrt::hstring, ResultType> evaluate(
        std::wstring_view sv, Environment::environment const& env);
} // Parser
