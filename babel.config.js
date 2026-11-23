// babel-preset-expo adds the react-native-worklets plugin by itself.
module.exports = function (api) {
  api.cache(true);
  return {
    presets: ['babel-preset-expo'],
  };
};
