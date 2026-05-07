declare module '@influxdata/influxdb-client' {
  export class Point {
    constructor(name: string);
    tag(key: string, value: string): this;
    floatField(key: string, value: number): this;
  }

  export interface WriteApi {
    writePoint(point: Point): void;
    flush(): Promise<void>;
  }

  export interface QueryApi {
    collectRows(
      query: string,
      rowMapper?: (row: any, tableMeta: any) => void
    ): Promise<any[]>;
  }

  export class InfluxDB {
    constructor(config: { url: string; token: string });
    getWriteApi(org: string, bucket: string, precision?: string): WriteApi;
    getQueryApi(org: string): QueryApi;
  }
}
