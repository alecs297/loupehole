typedef int (*LHFixtureFunction)(int);

static int LHFixtureBase(int value) {
    return value;
}

static LHFixtureFunction LHFixtureHead = LHFixtureBase;

int lh_fixture_value(int value) {
    return LHFixtureHead(value);
}

LHFixtureFunction lh_fixture_set_head(LHFixtureFunction head) {
    LHFixtureFunction previous = LHFixtureHead;
    LHFixtureHead = head;
    return previous;
}

int lh_fixture_unused(int value) {
    return value;
}
