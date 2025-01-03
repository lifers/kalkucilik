module;
#include <boost/multiprecision/cpp_dec_float.hpp>
#include <boost/parser/parser.hpp>
#include <boost/parser/transcode_view.hpp>
module Parser;

import WinRT;
import Environment;

namespace mp = boost::multiprecision;
namespace bp = boost::parser;
using val_t = mp::cpp_dec_float_100;

val_t const pi("3.141592653589793238462643383279502"
    "8841971693993751058209749445923078164062862089986280348253421170679");
val_t const e("2.7182818284590452353602874713526624"
    "977572470936999595749669676277240766303535475945713821785251664274");

//auto constexpr do_assign{ [](auto& ctx) {
//    val_t const val{ bp::_attr(ctx) };
//    bp::_val(ctx) = val;
//} };

// Lookup variable value
auto constexpr do_lookup{ [](auto& ctx) {
    auto const env{ bp::_globals(ctx) };
    auto const varname{ bp::_attr(ctx) };
    if (auto const val{ env.get(varname) }; !val.empty()) {
        bp::_val(ctx) = val_t(val);
    }
    else {
        bp::_pass(ctx) = false;
    }
} };

auto constexpr do_translate{ [](auto& ctx) {
    auto [a, b] { bp::_attr(ctx) };
    std::string str{ a };
    if (b.has_value()) {
        str += '.';
        str += b.value();
    }
    bp::_val(ctx) = val_t(str);
} };
auto constexpr do_translate_neg{ [](auto& ctx) {
    auto [a, b] { bp::_attr(ctx) };
    std::string str{ a };
    if (b.has_value()) {
        str += '.';
        str += b.value();
    }
    bp::_val(ctx) = val_t("-" + str);
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

template<typename Tag>
using calc_rule = bp::rule<Tag, val_t>;

calc_rule<class power_10_tag> constexpr power_10{ "power_10" };
calc_rule<class fac_uns_tag> constexpr fac_uns{ "fac_uns" };
calc_rule<class factor_tag> constexpr factor{ "factor" };
calc_rule<class exponent_tag> constexpr exponent{ "exponent" };
calc_rule<class term_tag> constexpr term{ "term" };
calc_rule<class expr_tag> constexpr expr{ "expression" };
bp::rule<class assign_tag, std::tuple<std::string, val_t>> constexpr assign{ "assignment" };

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

auto constexpr expr_def{
    term[do_id] >> *(('+' >> term[do_add]) | ('-' >> term[do_subt]))
};

auto constexpr assign_def{
    bp::lit("let") > identifier > bp::lit('=') > expr
};

BOOST_PARSER_DEFINE_RULES(
    power_10,
    fac_uns,
    factor,
    exponent,
    term,
    expr,
    assign
);

namespace Parser
{
    std::tuple<std::string, winrt::hstring, ResultType> evaluate(
        std::wstring_view sv,
        Environment::environment const& env) {
        if (sv.empty()) {
            return std::make_tuple("", L"", ResultType::Invalid);
        }

        val_t val;
        std::tuple<std::string, val_t> assign_res;
        
        if (bp::parse(sv | bp::as_utf16, bp::with_globals(assign, env), bp::ws, assign_res)) {
            auto [a, b]{ assign_res };
             return std::make_tuple(a, winrt::to_hstring(b.str()), ResultType::Assignment);
        }
        else if (bp::parse(sv | bp::as_utf16, bp::with_globals(expr, env), bp::ws, val)) {
            return std::make_tuple("", winrt::to_hstring(val.str()), ResultType::Expression);
        }
        else {
            return std::make_tuple("", L"", ResultType::Invalid);
        }
    }
} // Parser
