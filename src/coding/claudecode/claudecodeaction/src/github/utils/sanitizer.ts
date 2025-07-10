export function stripInvisibleCharacters(content: string): string {
  content = content.replace(/[\u200B\u200C\u200D\uFEFF]/g, "");
  content = content.replace(
    /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F]/g,
    "",
  );
  content = content.replace(/\u00AD/g, "");
  content = content.replace(/[\u202A-\u202E\u2066-\u2069]/g, "");
  return content;
}

export function stripMarkdownImageAltText(content: string): string {
  return content.replace(/!\[[^\]]{0,1000}\]\(/g, "![](");
}

export function stripMarkdownLinkTitles(content: string): string {
  content = content.replace(/(\[[^\]]{0,1000}\]\([^)]{0,1000})\s+"[^"]{0,1000}"/g, "$1");
  content = content.replace(/(\[[^\]]{0,1000}\]\([^)]{0,1000})\s+'[^']{0,1000}'/g, "$1");
  return content;
}

export function stripHiddenAttributes(content: string): string {
  content = content.replace(/\salt\s*=\s*["'][^"']{0,1000}["']/gi, "");
  content = content.replace(/\salt\s*=\s*[^\s>]{1,100}/gi, "");
  content = content.replace(/\stitle\s*=\s*["'][^"']{0,1000}["']/gi, "");
  content = content.replace(/\stitle\s*=\s*[^\s>]{1,100}/gi, "");
  content = content.replace(/\saria-label\s*=\s*["'][^"']{0,1000}["']/gi, "");
  content = content.replace(/\saria-label\s*=\s*[^\s>]{1,100}/gi, "");
  content = content.replace(/\sdata-[a-zA-Z0-9-]{1,50}\s*=\s*["'][^"']{0,1000}["']/gi, "");
  content = content.replace(/\sdata-[a-zA-Z0-9-]{1,50}\s*=\s*[^\s>]{1,100}/gi, "");
  content = content.replace(/\splaceholder\s*=\s*["'][^"']{0,1000}["']/gi, "");
  content = content.replace(/\splaceholder\s*=\s*[^\s>]{1,100}/gi, "");
  return content;
}

export function normalizeHtmlEntities(content: string): string {
  content = content.replace(/&#(\d+);/g, (_, dec) => {
    const num = parseInt(dec, 10);
    if (num >= 32 && num <= 126) {
      return String.fromCharCode(num);
    }
    return "";
  });
  content = content.replace(/&#x([0-9a-fA-F]+);/g, (_, hex) => {
    const num = parseInt(hex, 16);
    if (num >= 32 && num <= 126) {
      return String.fromCharCode(num);
    }
    return "";
  });
  return content;
}

export function sanitizeContent(content: string): string {
  content = stripHtmlComments(content);
  content = stripInvisibleCharacters(content);
  content = stripMarkdownImageAltText(content);
  content = stripMarkdownLinkTitles(content);
  content = stripHiddenAttributes(content);
  content = normalizeHtmlEntities(content);
  return content;
}

export const stripHtmlComments = (content: string) =>
  content.replace(/<!--[^]*?-->/g, "").replace(/<!--[^]*$/, "");
