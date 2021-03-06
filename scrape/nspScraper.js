import axios from 'axios';
import cheerio from 'cheerio';
import { detailUrl } from '../const';
import { log, toResultObject } from '../util';
import { nspDetailScrape } from './nspDetailScraper';

export const nspScrape = (results) => {
  log('info', 'Promises NSP resolved, scraping through HTML...');

  let processedData = [];
  let detailPromises = [];

  results.forEach(({ result }) => {
    const htmlResult = result.data;
    let $ = cheerio.load(htmlResult);

    $('.advisories-table tbody tr').each((idx, child) => {
      let scrapedData = {};

      const tableRow = $(child);
      scrapedData.title = tableRow.find('.advisory-title a').text();
      scrapedData.link = tableRow.find('.advisory-title a').attr('href');
      scrapedData.reportedAt = tableRow.find('.advisory-date span').html();

      scrapedData.moduleName = tableRow.find('.module-name a').text();
      scrapedData.moduleLink = tableRow.find('.module-name a').attr('href');
      scrapedData.vulnerableVersion = tableRow.find('.module-version span').first().html().replace(
          /\&gt\;/g, '>').replace(/\&lt\;/g, '<');
      scrapedData.patchedVersion = tableRow.find('.module-version span').last().html().replace(
          /\&gt\;/g, '>').replace(/\&lt\;/g, '<');

      scrapedData.severity = tableRow.find('span.cvss-score').html();
      scrapedData.rate = tableRow.find('span.cvss-rating').html();

      detailPromises.push(axios.get(`${detailUrl}${scrapedData.link}`));
      processedData[`${detailUrl}${scrapedData.link}`] = scrapedData;
    });
  });
  log('info', 'Finish curating object, gathering info from NSP detail pages...');
  return Promise.all(detailPromises.map(toResultObject)).then(nspDetailScrape(processedData));
};

export default nspScrape;
