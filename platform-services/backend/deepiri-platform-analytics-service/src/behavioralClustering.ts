import { Request, Response } from 'express';
import { createLogger } from '@deepiri/shared-utils';

const logger = createLogger('behavioral-clustering');

type DataPoint = number[];

interface Cluster {
  id: number;
  points: DataPoint[];
}

class BehavioralClusteringService {
  private clusters: Map<string, Cluster[]> = new Map();

  async analyze(req: Request, res: Response): Promise<void> {
    try {
      const { dataPoints, algorithm = 'kmeans', k = 5, eps = 0.5, minPoints = 3 } = req.body;
      
      if (!dataPoints || !Array.isArray(dataPoints)) {
        res.status(400).json({ error: 'Invalid dataPoints' });
        return;
      }

      let result;
      if (algorithm === 'dbscan') {
        result = await this.dbscanClustering(dataPoints, eps, minPoints);
      } else {
        result = await this.kMeansClustering(dataPoints, k);
      }

      res.json(result);
    } catch (error: any) {
      logger.error('Error in clustering analysis:', error);
      res.status(500).json({ error: 'Clustering analysis failed' });
    }
  }

  async getUserGroup(req: Request, res: Response): Promise<void> {
    try {
      const { userId } = req.params;
      // Placeholder - would determine user's cluster group
      res.json({ userId, group: 'default' });
    } catch (error: any) {
      logger.error('Error getting user group:', error);
      res.status(500).json({ error: 'Failed to get user group' });
    }
  }

  private async kMeansClustering(dataPoints: DataPoint[], k: number = 5) {
    try {
      const centroids = this._initializeCentroids(dataPoints, k);
      let clusters: DataPoint[][] = [];
      let changed = true;
      let iterations = 0;
      const maxIterations = 100;

      while (changed && iterations < maxIterations) {
        clusters = this._assignToClusters(dataPoints, centroids);
        const newCentroids = this._calculateCentroids(clusters);
        
        changed = this._centroidsChanged(centroids, newCentroids);
        centroids.splice(0, centroids.length, ...newCentroids);
        iterations++;
      }

      return {
        clusters,
        centroids,
        iterations
      };
    } catch (error) {
      logger.error('Error in K-means clustering:', error);
      throw error;
    }
  }

  private async dbscanClustering(dataPoints: DataPoint[], eps: number = 0.5, minPoints: number = 3) {
    try {
      const visited = new Set<number>();
      const clusters: Cluster[] = [];
      let clusterId = 0;

      for (let i = 0; i < dataPoints.length; i++) {
        if (visited.has(i)) continue;

        visited.add(i);
        const neighbors = this._getNeighbors(dataPoints, i, eps);

        if (neighbors.length < minPoints) {
          continue;
        }

        const cluster: DataPoint[] = [dataPoints[i]];
        clusterId++;

        for (let j = 0; j < neighbors.length; j++) {
          const neighborIdx = neighbors[j];
          if (!visited.has(neighborIdx)) {
            visited.add(neighborIdx);
            const neighborNeighbors = this._getNeighbors(dataPoints, neighborIdx, eps);
            if (neighborNeighbors.length >= minPoints) {
              neighbors.push(...neighborNeighbors);
            }
          }
          cluster.push(dataPoints[neighborIdx]);
        }

        clusters.push({
          id: clusterId,
          points: cluster
        });
      }

      return {
        clusters,
        noisePoints: dataPoints.filter((_, i) => !visited.has(i))
      };
    } catch (error) {
      logger.error('Error in DBSCAN clustering:', error);
      throw error;
    }
  }

  private _initializeCentroids(dataPoints: DataPoint[], k: number): DataPoint[] {
    const centroids: DataPoint[] = [];
    const indices = new Set<number>();
    
    while (centroids.length < k && indices.size < dataPoints.length) {
      const idx = Math.floor(Math.random() * dataPoints.length);
      if (!indices.has(idx)) {
        indices.add(idx);
        centroids.push([...dataPoints[idx]]);
      }
    }
    
    return centroids;
  }

  private _assignToClusters(dataPoints: DataPoint[], centroids: DataPoint[]): DataPoint[][] {
    const clusters = centroids.map(() => [] as DataPoint[]);
    
    dataPoints.forEach(point => {
      let minDist = Infinity;
      let clusterIdx = 0;
      
      centroids.forEach((centroid, idx) => {
        const dist = this._euclideanDistance(point, centroid);
        if (dist < minDist) {
          minDist = dist;
          clusterIdx = idx;
        }
      });
      
      clusters[clusterIdx].push(point);
    });
    
    return clusters;
  }

  private _calculateCentroids(clusters: DataPoint[][]): DataPoint[] {
    return clusters.map(cluster => {
      if (cluster.length === 0) return null as any;
      
      const dimensions = cluster[0].length;
      const centroid = new Array(dimensions).fill(0);
      
      cluster.forEach(point => {
        point.forEach((val, idx) => {
          centroid[idx] += val;
        });
      });
      
      return centroid.map(sum => sum / cluster.length);
    }).filter(c => c !== null);
  }

  private _centroidsChanged(oldCentroids: DataPoint[], newCentroids: DataPoint[]): boolean {
    if (oldCentroids.length !== newCentroids.length) return true;
    
    for (let i = 0; i < oldCentroids.length; i++) {
      const dist = this._euclideanDistance(oldCentroids[i], newCentroids[i]);
      if (dist > 0.001) return true;
    }
    
    return false;
  }

  private _getNeighbors(dataPoints: DataPoint[], pointIdx: number, eps: number): number[] {
    const neighbors: number[] = [];
    const point = dataPoints[pointIdx];
    
    dataPoints.forEach((otherPoint, idx) => {
      if (idx !== pointIdx) {
        const dist = this._euclideanDistance(point, otherPoint);
        if (dist <= eps) {
          neighbors.push(idx);
        }
      }
    });
    
    return neighbors;
  }

  private _euclideanDistance(point1: DataPoint, point2: DataPoint): number {
    let sum = 0;
    for (let i = 0; i < point1.length; i++) {
      sum += Math.pow(point1[i] - point2[i], 2);
    }
    return Math.sqrt(sum);
  }
}

export default new BehavioralClusteringService();

