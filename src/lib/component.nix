{ lib }: {

  types = lib.types // {
    symbol = lib.mkOptionType {
      name = "symbol";
      merge = mergeOneOption;
      check = s: ! lib.hasPrefix ":" s;
    };
    keyword = lib.mkOptionType {
      name = "keyword";
      merge = mergeOneOption;
      check = lib.hasPrefix ":";
    };
  };

}
