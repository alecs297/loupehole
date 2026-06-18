#include "LHProfile.h"

const LHProfile *LHProfileDefault(void) {
    static const LHProfile profile = {
        .version = 1
    };
    return &profile;
}
