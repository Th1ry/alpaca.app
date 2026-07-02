/// Compile-time default for extended depth (五档 2–5) HTTPS API.

///

/// App settings override this at runtime. Response JSON:

/// ```json

/// { "asks": [{"price": 1.23, "size": 100}], "bids": [{"price": 1.22, "size": 200}] }

/// ```

/// Use `{symbol}` in the URL template. Leave empty to use Alpaca BBO (买一/卖一) only.

class DepthApiConfig {

  DepthApiConfig._();



  static const urlTemplate = String.fromEnvironment(

    'DEPTH_API_URL',

    defaultValue: '',

  );

}

