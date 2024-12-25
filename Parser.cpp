module;
#include <boost/multiprecision/cpp_dec_float.hpp>
#include <boost/parser/parser.hpp>
#include <boost/unordered/unordered_flat_map.hpp>
module Parser;

import WinRT;

namespace mp = boost::multiprecision;
namespace bp = boost::parser;
namespace bu = boost::unordered;

mp::cpp_dec_float_100 const pi("3.141592653589793238462643383279502"
            "8841971693993751058209749445923078164062862089986280348253421170679");
mp::cpp_dec_float_100 const e("2.7182818284590452353602874713526624"
            "977572470936999595749669676277240766303535475945713821785251664274");

struct environment {
    bu::unordered_flat_map<std::string, mp::cpp_dec_float_100> variables;
};

// Handle variable assignment
auto constexpr do_assign{ [](auto& ctx) {
    auto vars{ bp::_locals(ctx) };
    auto varname { bp::_attr(ctx) };
    auto value{ bp::_val(ctx) };
    vars.variables[varname] = value; // Store variable
    bp::_val(ctx) = value; // Return the assigned value
} };

// Lookup variable value
auto constexpr do_lookup{ [](auto& ctx) {
    auto& vars = bp::_locals(ctx);
    auto varname = bp::_attr(ctx);
    if (vars.variables.find(varname) != vars.variables.end()) {
        bp::_val(ctx) = vars.variables[varname];
    } else {
        throw std::runtime_error("Undefined variable: " + varname);
    }
} };

auto constexpr do_translate{ [](auto& ctx) {
    auto [a, b] { bp::_attr(ctx) };
    std::string str{ a };
    if (b.has_value()) {
        str += '.';
        str += b.value();
    }
    bp::_val(ctx) = mp::cpp_dec_float_100(str);
} };
auto constexpr do_translate_neg{ [](auto& ctx) {
    auto [a, b] { bp::_attr(ctx) };
    std::string str{ a };
    if (b.has_value()) {
        str += '.';
        str += b.value();
    }
    bp::_val(ctx) = mp::cpp_dec_float_100("-" + str);
} };
auto constexpr do_power_10{ [](auto& ctx) { bp::_val(ctx) *= pow(10, bp::_attr(ctx)); } };
auto constexpr do_id{ [](auto& ctx) { bp::_val(ctx) = bp::_attr(ctx); } };
auto constexpr do_neg{ [](auto& ctx) { bp::_val(ctx) = -bp::_attr(ctx); } };
auto constexpr do_add{ [](auto& ctx) { bp::_val(ctx) += bp::_attr(ctx); } };
auto constexpr do_subt{ [](auto& ctx) { bp::_val(ctx) -= bp::_attr(ctx); } };
auto constexpr do_mult{ [](auto& ctx) { bp::_val(ctx) *= bp::_attr(ctx); } };
auto constexpr do_div{ [](auto& ctx) { bp::_val(ctx) /= bp::_attr(ctx); } };
auto constexpr do_sqrt{ [](auto& ctx) { bp::_val(ctx) = sqrt(bp::_attr(ctx)); } };
auto constexpr do_cbrt{ [](auto& ctx) { bp::_val(ctx) = cbrt(bp::_attr(ctx)); } };
auto constexpr do_ln{ [](auto& ctx) { bp::_val(ctx) = log(bp::_attr(ctx)); } };
auto constexpr do_pow{ [](auto& ctx) { bp::_val(ctx) = pow(bp::_val(ctx), bp::_attr(ctx)); } };
auto constexpr do_sin{ [](auto& ctx) { bp::_val(ctx) = sin(bp::_attr(ctx)); } };
auto constexpr do_cos{ [](auto& ctx) { bp::_val(ctx) = cos(bp::_attr(ctx)); } };
auto constexpr do_tan{ [](auto& ctx) { bp::_val(ctx) = tan(bp::_attr(ctx)); } };
auto constexpr do_abs{ [](auto& ctx) { bp::_val(ctx) = abs(bp::_attr(ctx)); } };
auto constexpr do_pi{ [](auto& ctx) { bp::_val(ctx) = pi; } };
auto constexpr do_e{ [](auto& ctx) { bp::_val(ctx) = e; } };

using val_t = mp::cpp_dec_float_100;
template<typename Tag>
using calc_rule = bp::rule<Tag, val_t>;

calc_rule<class power_10_tag> constexpr power_10{ "power_10" };
bp::rule<class fac_uns_tag, val_t, environment> constexpr fac_uns{ "fac_uns" };
calc_rule<class factor_tag> constexpr factor{ "factor" };
calc_rule<class exponent_tag> constexpr exponent{ "exponent" };
calc_rule<class term_tag> constexpr term{ "term" };
calc_rule<class assign_tag> constexpr assign{ "assignment" };
bp::rule<class expr_tag, val_t, environment> constexpr expr{ "expression" };

auto constexpr number{ bp::lexeme[+bp::digit >> -('.' >> +bp::digit)] };

auto constexpr identifier{ +(bp::char_('A', 'Z') | bp::char_('a', 'z')) };

auto constexpr power_10_def{ bp::lexeme['e' >> (
    number[do_translate]
    | ('+' >> number[do_translate])
    | ('-' >> number[do_translate_neg])
)] };

auto constexpr fac_uns_def{
    bp::lexeme[number[do_translate] >> power_10[do_power_10]]
    | number[do_translate]
    | bp::lit("pi")[do_pi]
    | bp::lit("e")[do_e]
    | ('(' >> expr > ')')[do_id]
    | (bp::lit("sqrt") >> '(' >> expr > ')')[do_sqrt]
    | (bp::lit("cbrt") >> '(' >> expr > ')')[do_cbrt]
    | (bp::lit("ln") >> '(' >> expr > ')')[do_ln]
    | (bp::lit("sin") >> '(' >> expr > ')')[do_sin]
    | (bp::lit("cos") >> '(' >> expr > ')')[do_cos]
    | (bp::lit("tan") >> '(' >> expr > ')')[do_tan]
    | (bp::lit("abs") >> '(' >> expr > ')')[do_abs]
    | identifier[do_lookup]
};

auto constexpr factor_def{
    fac_uns[do_id] | ('+' >> fac_uns[do_id]) | ('-' >> fac_uns[do_neg])
};

auto constexpr exponent_def{
    factor[do_id] >> *(('^' >> factor[do_pow]))
};

auto constexpr term_def{
    exponent[do_id] >> *(('*' >> exponent[do_mult]) | ('/' >> exponent[do_div]))
};

auto constexpr assign_def{
    bp::lit("let") >> identifier > bp::lit('=') > expr[do_assign]
};

auto constexpr expr_def{
    term[do_id] >> *(('+' >> term[do_add]) | ('-' >> term[do_subt]))
    | assign[do_assign]
};

BOOST_PARSER_DEFINE_RULES(power_10, fac_uns, factor, exponent, term, assign, expr);


namespace Parser
{
    winrt::hstring evaluate(std::wstring_view sv) {
        winrt::hstring result{};
        if (!sv.empty()) {
            std::string const input{ winrt::to_string(sv) };
            mp::cpp_dec_float_100 val{ 0 };

            if (bp::parse(input, expr, bp::ws, val)) {
                result = winrt::to_hstring(val.str());
            }
        }

        return result;
    }
} // Parser