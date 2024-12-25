export module Parser;

import WinRT;

namespace Parser
{
    export winrt::hstring evaluate(std::wstring_view sv);
} // Parser