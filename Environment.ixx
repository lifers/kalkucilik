module;
#include <boost/unordered/unordered_flat_map.hpp>
export module Environment;

namespace bu = boost::unordered;

namespace Environment
{
    export class environment {
    public:
        void set(std::string const& name, std::string const& value) {
            variables[name] = value;
        }

        std::string get(std::string const& name) const {
            if (auto const it{ variables.find(name) }; it != variables.end()) {
                return it->second;
            }
            else {
                return "";
            }
        }
    private:
        bu::unordered_flat_map<std::string, std::string> variables;
    };
} // Environment