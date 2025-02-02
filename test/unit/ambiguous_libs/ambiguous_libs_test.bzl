"""Unittests for ambiguous native dependencies."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//rust:defs.bzl", "rust_binary", "rust_library", "rust_proc_macro", "rust_shared_library", "rust_static_library")

def _ambiguous_deps_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    rustc_action = [action for action in tut.actions if action.mnemonic == "Rustc"][0]

    # We depend on two C++ libraries named "native_dep", which we need to pass to the command line
    # in the form of "-lstatic=native-dep-{hash}.a or "-lstatic=native-dep.pic-{hash}.a.
    # Note that the second form should actually be "-lstatic=native-dep-{hash}.pic.a instead.
    link_args = [arg for arg in rustc_action.argv if arg.startswith("-lstatic=native_dep")]
    asserts.equals(env, 2, len(link_args))
    asserts.false(env, link_args[0] == link_args[1])

    return analysistest.end(env)

ambiguous_deps_test = analysistest.make(_ambiguous_deps_test_impl)

def _create_test_targets():
    rust_library(
        name = "rlib_with_ambiguous_deps",
        srcs = ["foo.rs"],
        edition = "2018",
        deps = [
            "//test/unit/ambiguous_libs/first_dep:native_dep",
            "//test/unit/ambiguous_libs/second_dep:native_dep",
        ],
    )

    rust_binary(
        name = "binary",
        srcs = ["bin.rs"],
        edition = "2018",
        deps = [":rlib_with_ambiguous_deps"],
    )

    rust_proc_macro(
        name = "proc_macro",
        srcs = ["foo.rs"],
        edition = "2018",
        deps = [":rlib_with_ambiguous_deps"],
    )

    rust_shared_library(
        name = "shared_library",
        srcs = ["foo.rs"],
        edition = "2018",
        deps = [":rlib_with_ambiguous_deps"],
    )

    rust_static_library(
        name = "static_library",
        srcs = ["foo.rs"],
        edition = "2018",
        deps = [":rlib_with_ambiguous_deps"],
    )

    ambiguous_deps_test(
        name = "bin_with_ambiguous_deps_test",
        target_under_test = ":binary",
    )
    ambiguous_deps_test(
        name = "staticlib_with_ambiguous_deps_test",
        target_under_test = ":static_library",
    )
    ambiguous_deps_test(
        name = "proc_macro_with_ambiguous_deps_test",
        target_under_test = ":proc_macro",
    )
    ambiguous_deps_test(
        name = "cdylib_with_ambiguous_deps_test",
        target_under_test = ":shared_library",
    )

def ambiguous_libs_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """
    _create_test_targets()

    native.test_suite(
        name = name,
        tests = [
            ":bin_with_ambiguous_deps_test",
            ":staticlib_with_ambiguous_deps_test",
            ":proc_macro_with_ambiguous_deps_test",
            ":cdylib_with_ambiguous_deps_test",
        ],
    )
