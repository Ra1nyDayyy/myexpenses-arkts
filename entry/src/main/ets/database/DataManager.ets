/**
 * 数据管理服务：CSV 导出/导入、数据库备份/恢复
 * 对应 Android BackupRestoreActivity + CsvImportActivity + Export 功能
 */
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Repository } from './Repository';
import { Transaction, CrStatus } from '../model/Transaction';
import { Account } from '../model/Account';
import { Category } from '../model/Category';
import { PaymentMethod } from '../model/SupportEntities';
import { formatMoney } from '../model/Money';
import { currencyByCode } from '../model/CurrencyUnit';
import { formatDate } from '../common/FormatUtils';

const TAG = 'MyExpenses';

export class DataManager {
  private static instance: DataManager | null = null;
  private repository: Repository = Repository.getInstance();
  private context: common.Context | null = null;

  static getInstance(): DataManager {
    if (!DataManager.instance) {
      DataManager.instance = new DataManager();
    }
    return DataManager.instance;
  }

  setContext(ctx: common.Context): void {
    this.context = ctx;
  }

  /**
   * 生成交易 CSV 文本（对齐安卓 CSV 导出）
   * 列：日期,金额,类型,分类,备注,收款人,付款方式,账户,状态
   */
  async buildCsv(): Promise<string> {
    const txs = await this.repository.getAllTransactions();
    let csv = '日期,金额,类型,分类,备注,收款人,付款方式,账户,状态\n';
    for (let t of txs) {
      const row: string[] = [];
      row.push(formatDate(t.date));
      const symbol = currencyByCode(t.currency).symbol;
      row.push(`${symbol}${formatMoney(t.amount, currencyByCode(t.currency).fractionDigits)}`);
      if (t.isTransfer()) {
        row.push('转账');
      } else if (t.amount > 0) {
        row.push('收入');
      } else {
        row.push('支出');
      }
      row.push(this.escapeCsv(t.categoryPath || ''));
      row.push(this.escapeCsv(t.comment || ''));
      row.push(this.escapeCsv(t.payeeName || ''));
      row.push(this.escapeCsv(t.methodLabel || ''));
      row.push(this.escapeCsv(t.accountLabel || ''));
      row.push(this.statusLabel(t.crStatus));
      csv += row.join(',') + '\n';
    }
    return csv;
  }

  private escapeCsv(v: string): string {
    if (v.indexOf(',') >= 0 || v.indexOf('"') >= 0 || v.indexOf('\n') >= 0) {
      return '"' + v.replace(/"/g, '""') + '"';
    }
    return v;
  }

  private statusLabel(status: string): string {
    if (status === 'RECONCILED') { return '已对账'; }
    if (status === 'CLEARED') { return '已清算'; }
    if (status === 'VOID') { return '作废'; }
    return '未清算';
  }

  /**
   * 导出 CSV：通过文件选择器保存到用户目录
   */
  async exportCsv(): Promise<boolean> {
    if (!this.context) {
      return false;
    }
    const csv = await this.buildCsv();
    try {
      const options = new picker.DocumentSaveOptions();
      options.newFileNames = [`myexpenses_export_${Date.now()}.csv`];
      const docSave = new picker.DocumentViewPicker(this.context);
      const uris: string[] = await docSave.save(options);
      if (uris && uris.length > 0) {
        const file = fs.openSync(uris[0], fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
        fs.writeSync(file.fd, csv);
        fs.closeSync(file);
        return true;
      }
    } catch (e) {
      const err = e as BusinessError;
      hilog.error(0x0000, TAG, 'exportCsv failed: ' + JSON.stringify(err));
    }
    return false;
  }

  /**
   * 备份数据库：把数据库文件复制到用户选择位置
   */
  async backupDatabase(): Promise<boolean> {
    if (!this.context) {
      return false;
    }
    try {
      const basePath = this.context.databaseDir;
      // rdb 默认存储于 <databaseDir>/entry/rdb/<dbname>，需精确到实际文件
      const srcFile = `${basePath}/rdb/myexpenses.db`;
      if (!fs.accessSync(srcFile)) {
        hilog.error(0x0000, TAG, 'backup src not found: ' + srcFile);
        return false;
      }
      const options = new picker.DocumentSaveOptions();
      options.newFileNames = [`myexpenses_backup_${Date.now()}.db`];
      const docSave = new picker.DocumentViewPicker(this.context);
      const uris: string[] = await docSave.save(options);
      if (uris && uris.length > 0) {
        const src = fs.openSync(srcFile, fs.OpenMode.READ_ONLY);
        const dst = fs.openSync(uris[0], fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
        const bufSize = 1024 * 1024;
        const buf = new ArrayBuffer(bufSize);
        let read = fs.readSync(src.fd, buf);
        while (read > 0) {
          fs.writeSync(dst.fd, buf.slice(0, read));
          read = fs.readSync(src.fd, buf);
        }
        fs.closeSync(src);
        fs.closeSync(dst);
        return true;
      }
    } catch (e) {
      const err = e as BusinessError;
      hilog.error(0x0000, TAG, 'backupDatabase failed: ' + JSON.stringify(err));
    }
    return false;
  }

  /**
   * 恢复数据库：从用户选择的备份文件复制到数据库目录
   * 注意：恢复前需提示用户重启应用生效
   */
  async restoreDatabase(): Promise<boolean> {
    if (!this.context) {
      return false;
    }
    try {
      const docPicker = new picker.DocumentViewPicker(this.context);
      const uris: string[] = await docPicker.select({ maxSelectNumber: 1 });
      if (uris && uris.length > 0) {
        const basePath = this.context.databaseDir;
        const dstFile = `${basePath}/rdb/myexpenses.db`;
        const src = fs.openSync(uris[0], fs.OpenMode.READ_ONLY);
        const dst = fs.openSync(dstFile, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
        const bufSize = 1024 * 1024;
        const buf = new ArrayBuffer(bufSize);
        let read = fs.readSync(src.fd, buf);
        while (read > 0) {
          fs.writeSync(dst.fd, buf.slice(0, read));
          read = fs.readSync(src.fd, buf);
        }
        fs.closeSync(src);
        fs.closeSync(dst);
        return true;
      }
    } catch (e) {
      const err = e as BusinessError;
      hilog.error(0x0000, TAG, 'restoreDatabase failed: ' + JSON.stringify(err));
    }
    return false;
  }

  /**
   * 导入 CSV（对齐安卓 CsvImportActivity）
   * 支持导出的列格式：日期,金额,类型,分类,备注,收款人,付款方式,账户,状态
   * 返回导入成功条数；-1 表示取消或失败
   */
  async importCsv(): Promise<number> {
    if (!this.context) {
      return -1;
    }
    try {
      const docPicker = new picker.DocumentViewPicker(this.context);
      const uris: string[] = await docPicker.select({ maxSelectNumber: 1 });
      if (!uris || uris.length === 0) {
        return -1;
      }
      const file = fs.openSync(uris[0], fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(file.fd);
      const buf = new ArrayBuffer(stat.size);
      const len = fs.readSync(file.fd, buf);
      fs.closeSync(file);
      const bytes = new Uint8Array(buf.slice(0, len));
      let content = '';
      for (let i = 0; i < bytes.length; i++) {
        content += String.fromCharCode(bytes[i]);
      }
      const lines = content.split('\n').filter((l: string) => l.trim().length > 0);
      if (lines.length === 0) {
        return 0;
      }
      // 跳过表头
      const dataLines = lines.slice(1);
      const accounts = await this.repository.getAccounts();
      const categories = await this.repository.getCategories();
      const methods = await this.repository.getPaymentMethods();
      let imported = 0;
      for (const line of dataLines) {
        const cols = this.parseCsvLine(line);
        if (cols.length < 9) {
          continue;
        }
        const t = new Transaction();
        t.date = this.parseDate(cols[0]);
        t.amount = this.parseAmount(cols[1]);
        // 类型
        const typeLabel = cols[2];
        if (typeLabel === '转账') {
          t.transferAccountId = -1; // 简化：转账导入跳过（需双向账户）
          continue;
        }
        // 分类
        const cat = categories.find((c: Category) => c.label === cols[3]);
        t.categoryId = cat ? cat.id : -1;
        t.comment = cols[4];
        // 收款人
        if (cols[5].length > 0) {
          t.payeeId = await this.repository.findOrCreatePayee(cols[5]);
        } else {
          t.payeeId = -1;
        }
        // 付款方式
        const method = methods.find((m: PaymentMethod) => m.label === cols[6]);
        t.methodId = method ? method.id : -1;
        // 账户
        const acc = accounts.find((a: Account) => a.label === cols[7]);
        if (!acc) {
          continue; // 账户不存在则跳过该行
        }
        t.accountId = acc.id;
        t.currency = acc.currency;
        t.crStatus = this.parseStatus(cols[8]);
        t.valueDate = t.date;
        t.uuid = '';
        await this.repository.insertTransaction(t);
        imported++;
      }
      return imported;
    } catch (e) {
      const err = e as BusinessError;
      hilog.error(0x0000, TAG, 'importCsv failed: ' + JSON.stringify(err));
      return -1;
    }
  }

  private parseCsvLine(line: string): string[] {
    const result: string[] = [];
    let cur = '';
    let inQuotes = false;
    for (let i = 0; i < line.length; i++) {
      const ch = line[i];
      if (inQuotes) {
        if (ch === '"') {
          if (i + 1 < line.length && line[i + 1] === '"') {
            cur += '"';
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          cur += ch;
        }
      } else if (ch === '"') {
        inQuotes = true;
      } else if (ch === ',') {
        result.push(cur);
        cur = '';
      } else {
        cur += ch;
      }
    }
    result.push(cur);
    return result;
  }

  private parseAmount(v: string): number {
    // 去除货币符号和非数字
    const cleaned = v.replace(/[^\d.\-]/g, '');
    const n = parseFloat(cleaned) || 0;
    return Math.round(n * 100);
  }

  private parseDate(v: string): number {
    // 支持 YYYY-MM-DD 或 YYYY年M月D日
    const m = v.match(/(\d{4})[-年\/.](\d{1,2})[-月\/.](\d{1,2})/);
    if (m) {
      return Math.floor(new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3])).getTime() / 1000);
    }
    return Math.floor(Date.now() / 1000);
  }

  private parseStatus(v: string): CrStatus {
    if (v === '已对账') { return CrStatus.RECONCILED; }
    if (v === '已清算') { return CrStatus.CLEARED; }
    if (v === '作废') { return CrStatus.VOID; }
    return CrStatus.UNRECONCILED;
  }
}