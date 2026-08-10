import { util } from '@kit.ArkTS';

/**
 * 极简 PDF 生成器（不依赖 HMS PDFKit，纯 OpenHarmony 可用）
 *
 * 背景：@kit.PDFKit 底层为 @hms:officeservice.pdfservice（华为 HMS 专属服务），
 * 纯 OpenHarmony 设备/模拟器上运行时加载失败（Load native module failed）。
 * 因此这里改为：用 Canvas 把资产负债表渲染成 JPEG 图片，再手动构造 PDF 文件
 * 内嵌该图片（XObject /DCTDecode）。中文字体由 Canvas 系统字体渲染，无需嵌入字体。
 */

/** 将 data URL（如 data:image/jpeg;base64,xxx）解码为字节数组 */
export function base64DataUrlToBytes(dataUrl: string): Uint8Array {
  const comma = dataUrl.indexOf(',');
  const b64 = comma >= 0 ? dataUrl.substring(comma + 1) : dataUrl;
  const helper = new util.Base64Helper();
  return helper.decodeSync(b64);
}

/** ASCII 字符串转字节（PDF 结构均为 ASCII） */
function asciiBytes(s: string): Uint8Array {
  const out = new Uint8Array(s.length);
  for (let i = 0; i < s.length; i++) {
    out[i] = s.charCodeAt(i) & 0xff;
  }
  return out;
}

function concatBytes(parts: Uint8Array[]): Uint8Array {
  let total = 0;
  for (const p of parts) {
    total += p.length;
  }
  const out = new Uint8Array(total);
  let off = 0;
  for (const p of parts) {
    out.set(p, off);
    off += p.length;
  }
  return out;
}

function fmtNum(v: number): string {
  // 去掉多余小数位（最多保留 3 位）
  return v.toFixed(3).replace(/\.?0+$/, '');
}

/**
 * 构建单页 PDF，内嵌一张 JPEG 图片（DCTDecode），图片按比例缩放居中。
 *
 * @param jpeg  JPEG 二进制数据
 * @param imgW  图片像素宽
 * @param imgH  图片像素高
 * @param pageW 页面宽度（pt，A4 = 595）
 * @param pageH 页面高度（pt，A4 = 842）
 * @returns PDF 文件字节
 */
export function buildImagePdf(jpeg: Uint8Array, imgW: number, imgH: number, pageW: number, pageH: number): Uint8Array {
  // 图片缩放至适配页面并居中
  const scale = Math.min(pageW / imgW, pageH / imgH);
  const w = imgW * scale;
  const h = imgH * scale;
  const x = (pageW - w) / 2;
  const y = (pageH - h) / 2;

  const content = `q\n${fmtNum(w)} 0 0 ${fmtNum(h)} ${fmtNum(x)} ${fmtNum(y)} cm\n/Im0 Do\nQ\n`;
  const contentBytes = asciiBytes(content);

  // 各对象文本（不含图片流，图片流单独拼接）
  const obj1 = '<< /Type /Catalog /Pages 2 0 R >>';
  const obj2 = '<< /Type /Pages /Kids [3 0 R] /Count 1 >>';
  const obj3 = `<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${fmtNum(pageW)} ${fmtNum(pageH)}] /Resources << /XObject << /Im0 4 0 R >> >> /Contents 5 0 R >>`;
  const obj5 = `<< /Length ${contentBytes.length} >>\nstream\n${content}endstream`;

  // 组装字节：header + 5 个对象 + xref + trailer
  const parts: Uint8Array[] = [];
  parts.push(asciiBytes('%PDF-1.4\n'));
  const offsets: number[] = [0, 0, 0, 0, 0];
  let pos = 0;

  // 对象1
  offsets[0] = pos;
  parts.push(asciiBytes(`1 0 obj\n${obj1}\nendobj\n`));
  pos += asciiBytes(`1 0 obj\n${obj1}\nendobj\n`).length;
  // 对象2
  offsets[1] = pos;
  parts.push(asciiBytes(`2 0 obj\n${obj2}\nendobj\n`));
  pos += asciiBytes(`2 0 obj\n${obj2}\nendobj\n`).length;
  // 对象3
  offsets[2] = pos;
  parts.push(asciiBytes(`3 0 obj\n${obj3}\nendobj\n`));
  pos += asciiBytes(`3 0 obj\n${obj3}\nendobj\n`).length;
  // 对象4（图片流：头部文本 + 二进制 + 尾部文本）
  const imgHead = asciiBytes(`4 0 obj\n<< /Type /XObject /Subtype /Image /Width ${imgW} /Height ${imgH} /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length ${jpeg.length} >>\nstream\n`);
  const imgTail = asciiBytes('\nendstream\nendobj\n');
  offsets[3] = pos;
  parts.push(imgHead);
  pos += imgHead.length;
  parts.push(jpeg);
  pos += jpeg.length;
  parts.push(imgTail);
  pos += imgTail.length;
  // 对象5
  offsets[4] = pos;
  parts.push(asciiBytes(`5 0 obj\n${obj5}\nendobj\n`));
  pos += asciiBytes(`5 0 obj\n${obj5}\nendobj\n`).length;

  // xref
  const xrefStart = pos;
  const xrefLines = ['xref\n', '0 6\n', '0000000000 65535 f \n'];
  for (let i = 0; i < 5; i++) {
    xrefLines.push(`${offsets[i].toString().padStart(10, '0')} 00000 n \n`);
  }
  const xrefText = xrefLines.join('');
  parts.push(asciiBytes(xrefText));
  pos += xrefText.length;

  const trailerText = `trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n${xrefStart}\n%%EOF\n`;
  parts.push(asciiBytes(trailerText));

  return concatBytes(parts);
}